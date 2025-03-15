#!/bin/env ruby
# encoding: utf-8
class JournalsController < ApplicationController
  load_and_authorize_resource

  include Pagy::Backend

  helper JournalsHelper

  # GET /journals
  # GET /journals.json
  def index
    if (params[:unit_id] && params[:journal_type_id] && params[:year])
      journal = Journal.find_by_unit_and_year_and_type(Unit.find(params[:unit_id]), params[:year], JournalType.find(params[:journal_type_id]))
      if journal.nil?
        # if there is no such Journal - just create one

        if current_user.is_superadmin && params[:year].to_i == Time.now.year - 1
          # only superadmin can create journal for the previous year
          journal = Journal.get_previous_for_type(params[:unit_id], params[:journal_type_id])
        else
          journal = Journal.get_current_for_type(params[:unit_id], params[:journal_type_id])
        end
      end
      session[:current_unit_id] = journal.unit.id
      session[:current_year] = journal.year
      redirect_to journal
      return
    else
      redirect_to default_finance_journal_path
      return
    end
  end

  # GET /journals/1
  # GET /journals/1.json
  def show
    #override CanCan's auto-fetched journal
    @journal = Journal.includes(:journal_grants, entries: { items: [:category, :grants] }).find_by_id(@journal.id)

    if @journal.nil? or @journal.unit.is_active == false
      redirect_to home_url, alert: "Nie znaleziono księgi"
      return
    end

    authorize! :show, @journal

    # Zapisanie bieżącego kontekstu w sesji
    session[:current_year] = @journal.year
    session[:current_unit_id] = @journal.unit.id

    unless @journal.verify_journal
      flash.now[:alert] = @journal.errors.values.join("<br/>")
    end

    if @journal.nil? or @journal.unit.is_active == false
      flash.keep
      redirect_to default_finance_journal_path
    end

    # Cachowanie kategorii w pamięci sesji
    @categories_expense = fetch_categories(@journal.year, true)
    @categories_income = fetch_categories(@journal.year, false)
    
    # Sortowanie wpisów z uwzględnieniem podpozycji
    all_entries = if @journal.journal_type_id == JournalType::BANK_TYPE_ID
      # Dla księgi bankowej: sortowanie po dacie, a następnie najpierw wpisy główne, a potem podpozycje
      # Dodajemy sortowanie po parent_entry_id, aby upewnić się, że podpozycje są zawsze przypisane do właściwego wpisu głównego
      @journal.entries.includes({ items: [:category, :grants, { item_grants: :grant }] })
              .order('date ASC', 'CASE WHEN is_subentry THEN parent_entry_id ELSE id END ASC', 'is_subentry ASC', 'subentry_position ASC', 'id ASC')
    else
      # Dla pozostałych ksiąg: standardowe sortowanie
      @journal.entries.includes({ items: [:category, :grants, { item_grants: :grant }] })
              .order('date', 'id')
    end

    if params[:items].blank?
      @items = nil
      @entries = all_entries
      @page = 0
    else
      @items = params[:items].to_i
      @pagy, @entries = pagy(all_entries, page: params[:page], items: @items)
      @page = @pagy.page
    end

    @start_position = @page < 1 ? 0 : (@page - 1) * @items.to_i
    
    # Cachowanie dostępnych dla użytkownika jednostek
    @user_units = fetch_user_units(current_user)
    
    # Cachowanie lat dla bieżącej jednostki i typu księgi
    @years = fetch_journal_years(@journal.unit, @journal.journal_type)
    
    # Cachowanie dotacji dla roku
    @grants_by_journal_year = fetch_grants_by_year(@journal.year)

    if current_user.is_superadmin
      @years << Time.now.year - 1
      @years.uniq!
    end

    @years.sort!

    respond_to do |format|
      format.html { # show.html.erb
        @pdf_report_link = journal_path(:format => :pdf)
        @csv_report_link = journal_path(:format => :csv)
      }
      format.json { render json: @journal }
      format.pdf {
        @entries = all_entries
        @generation_time = Time.now
        render pdf: "#{journal_type_prefix(@journal.journal_type)}_#{get_time_postfix}",
               template: 'journals/show',
               layout: 'pdf',
               page_size: 'A4',
               orientation: 'Landscape',
               margin: {
                 top: 10,
                 bottom: 15,
                 left: 10,
                 right: 10
               },
               footer: {
                 font_size: 8,
                 left: "#{current_user.email}, #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}",
                 center: "#{request.host_with_port}",
                 right: 'Strona [page] z [topage]',
                 spacing: 5
               },
               show_as_html: params.key?('debug')
      }
      format.csv {
        @entries = all_entries
        render csv: "#{journal_type_prefix(@journal.journal_type)}_#{get_time_postfix}"
      }
    end
  end

  def default
    # get default journal
    journal_type = JournalType.find(params[:journal_type_id].to_i)

    current_unit_id = session[:current_unit_id].to_i
    current_unit_id = nil if current_unit_id == 0

    current_year = session[:current_year].to_i
    current_year = nil if current_year == 0

    @journal = Journal.get_default(journal_type, current_user, current_unit_id, current_year)
    unless @journal.nil?
      flash.keep
      redirect_to journal_path(@journal)
    else
      respond_to do |format|
        format.html # default.html.erb
      end
    end
  end

  # GET /journals/1/open
  def open
    @journal = Journal.find(params[:id])

    respond_to do |format|
      if @journal.open
        format.html { redirect_to journal_path(@journal), notice: 'Książka otwarta.' }
        format.json { render json: @journal, status: :opened, location: @journal }
      else
        format.html { redirect_to journals_url, alert: "Błąd otwierania książki: " + @journal.errors.full_messages.join(', ') }
        format.json { render json: @journal.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /journals/1/close
  def close
    @journal = Journal.find(params[:id])

    respond_to do |format|
      if @journal.close
        format.html { redirect_to journal_path(@journal), notice: 'Książka zamknięta.' }
        format.json { render json: @journal, status: :closed, location: @journal }
      else
        format.html { redirect_to journals_url, alert: "Błąd zamykania książki: " + @journal.errors.values.join(', ') }
        format.json { render json: @journal.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /journals/1/close_to
  def close_to
    @journal = Journal.find(params[:id])
    blocked_to = params[:journal_blocked_to_hidden_input].to_date

    if blocked_to.blank?
      redirect_to @journal
      return
    end

    respond_to do |format|
      if @journal.close(blocked_to)
        format.html { redirect_to journal_path(@journal), notice: 'Książka zamknięta.' }
      else
        format.html { redirect_to journals_url, alert: "Błąd zamykania książki: " + @journal.errors.values.join(', ') }
      end
    end
  end

  # GET /journals/close_old
  def close_old
    respond_to do |format|
      Journal.close_old_open(session[:current_year].to_i)

      format.html { redirect_to all_finance_report_path}
    end
  end

  # GET /journals/open_current
  def open_current
    respond_to do |format|
      Journal.open_all_by_year(session[:current_year].to_i)

      format.html { redirect_back(fallback_location: root_path) }
    end
  end

  # GET /journals/close_current
  def close_current
    respond_to do |format|
      Journal.close_all_by_year(session[:current_year].to_i)

      format.html { redirect_back(fallback_location: root_path) }
    end
  end


  # POST /journals/close_to
  def close_to_current
    current_year = session[:current_year].to_i
    blocked_to = params[:block_all_journals_to_hidden_input].to_date

    if blocked_to.blank? then
      redirect_back(fallback_location: root_path)
      return
    end

    respond_to do |format|
      Journal.close_all_by_year(current_year, blocked_to)
      format.html { redirect_back(fallback_location: root_path) }
    end
  end

  private

  def get_time_postfix
    @generation_time.strftime('%Y%m%d%H%M%S')
  end

  def journal_type_prefix(journal_type)
    'ksiazka_' + journal_type.to_s.split(' ')[1]
  end

  def journal_params
    params.require(:journal).permit(:journal_type_id, :unit_id, :year, :is_open)
  end
  
  # Metody pomocnicze do cachowania często używanych danych
  
  # Cachowanie kategorii
  def fetch_categories(year, is_expense)
    cache_key = "categories_#{year}_#{is_expense}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      Category.find_by_year_and_type(year, is_expense)
    end
  end
  
  # Cachowanie jednostek dostępnych dla użytkownika
  def fetch_user_units(user)
    cache_key = "user_units_#{user.id}_#{user.updated_at.to_i}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      Unit.find_by_user(user)
    end
  end
  
  # Cachowanie lat dla jednostki i typu księgi
  def fetch_journal_years(unit, journal_type)
    cache_key = "journal_years_#{unit.id}_#{journal_type.id}_#{unit.updated_at.to_i}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      unit.find_journal_years(journal_type)
    end
  end
  
  # Cachowanie dotacji dla roku
  def fetch_grants_by_year(year)
    cache_key = "grants_by_year_#{year}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      Grant.get_by_year(year)
    end
  end
end
