class EntriesController < ApplicationController
  # GET /entries/1
  # GET /entries/1.json
  def show
    @entry = Entry.find(params[:id])
    authorize! :read, @entry
    @categories = Category.where(:year => @entry.journal.year, :is_expense => @entry.is_expense)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @entry }
    end
  end

  # GET /entries/new
  # GET /entries/new.json
  def new
    @journal = Journal.find(params[:journal_id])
    @other_journals = @journal.journals_for_linked_entry
    @entry = Entry.new(:is_expense => params[:is_expense], :journal_id => params[:journal_id])
    authorize! :create, @entry
    @entry.items = []
    create_empty_items(@entry, @journal.year)
    
    @linked_entry = create_empty_items_in_linked_entry(@entry)
    @referer = request.referer

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @entry }
    end
  end

  # POST /entries
  # POST /entries.json
  # creates Entry and related Items
  def create
    @referer = params[:entry][:referer]
    @entry = Entry.new(entry_params)
   
    if params[:is_linked]
      linked_entry = Entry.new(params[:linked_entry])
      linked_entry = copy_to_linked_entry(@entry, linked_entry)
      @entry.linked_entry = linked_entry
    end

    authorize! :create, @entry

    respond_to do |format|
      # Próba zapisania wpisu
      begin
        save_success = @entry.save
      rescue => e
        # Obsługa błędów podczas zapisywania
        Rails.logger.error("Błąd podczas tworzenia wpisu: #{e.message}")
        save_success = false
        @entry.errors.add(:base, "Wystąpił błąd podczas zapisywania: #{e.message}")
      end
      
      if save_success
        format.html do
          # Zawsze wracaj do strony, z której przyszedł użytkownik (referer),
          # a jeśli referer nie istnieje, wróć do widoku książki
          flash[:notice] = 'Wpis utworzony'
          redirect_destination = if @referer.present?
            @referer
          else
            journal_path(@entry.journal)
          end
          
          redirect_to redirect_destination
        end
        format.json { render json: @entry, status: :created, location: @entry }
      else
        @journal = @entry.journal
        @categories = Category.where(:year => @entry.journal.year, :is_expense => @entry.is_expense)
        @sorted_items = @entry.items.sort_by {|item| item.category&.position.to_s }

        format.html { render action: "new" }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /entries/1/edit
  def edit
    @entry = Entry.find(params[:id])
    authorize! :update, @entry
    @journal = @entry.journal
    @other_journals = @journal.journals_for_linked_entry
    
    # Sprawdź, czy to księga bankowa z auto_bank_import
    @is_auto_import_bank = @journal.journal_type_id == JournalType::BANK_TYPE_ID && @journal.unit.auto_bank_import
    
    # Sprawdź, czy zmieniono typ wpisu
    if params[:type_changed].present?
      # Pobieramy kategorie zgodne z NOWYM typem wpisu (przeciwnym do oryginalnego)
      @categories = Category.where(:year => @entry.journal.year, :is_expense => !@entry.is_expense)
      # Aktualizujemy is_expense w entry do wyświetlenia właściwego formularza
      @entry.is_expense = !@entry.is_expense
      # Zapisujemy informację o zmianie typu w sesji dla celów bezpieczeństwa
      session[:entry_type_changed] = true
    else
      # Standardowe zachowanie - pobieramy kategorie zgodne z obecnym typem wpisu
      @categories = Category.where(:year => @entry.journal.year, :is_expense => @entry.is_expense)
      # Czyścimy informację o zmianie typu
      session[:entry_type_changed] = nil
    end
    
    create_empty_items(@entry, @journal.year)

    @linked_entry = create_empty_items_in_linked_entry(@entry)

    @sorted_items = @entry.items.sort_by {|item| item.category.position.to_s}
    @referer = request.referer
    
    # Jeśli referer nie istnieje lub prowadzi do nieprawidłowej strony, użyj widoku książki jako fallback
    if @referer.blank? || !(@referer =~ /journals/)
      @referer = journal_path(@journal)
    end
  end

  # PUT /entries/1
  # PUT /entries/1.json
  def update
    @referer = params[:entry][:referer]
    @entry = Entry.find(params[:id])
    authorize! :update, @entry
    @journal = @entry.journal
    @other_journals = @journal.journals_for_linked_entry
    
    # Sprawdź, czy to księga bankowa z auto_bank_import
    is_auto_import_bank = @journal.journal_type_id == JournalType::BANK_TYPE_ID && @journal.unit.auto_bank_import
    
    # Jeśli zwykły użytkownik próbuje zmienić datę wpisu w księdze auto_bank_import, przywróć oryginalną datę
    if is_auto_import_bank && !current_user.is_superadmin && params[:entry][:date] != @entry.date.to_s
      # Ustaw datę na oryginalną wartość
      params[:entry][:date] = @entry.date.to_s
      flash[:alert] = "Data wpisu w księgach bankowych z auto-importem może być zmieniona tylko przez administratora."
    end
    
    # Zapisz oryginalny typ wpisu przed zmianą
    original_is_expense = @entry.is_expense
    
    # Obsługa linked_entry (powiązanego wpisu)
    if params[:is_linked]
      if @entry.linked_entry
        # Jeśli linked_entry już istnieje, aktualizuj go
        if params[:linked_entry]
          @entry.linked_entry.update_attributes(params[:linked_entry])
          linked_entry = @entry.linked_entry
        end
      else
        # Jeśli linked_entry nie istnieje, utwórz nowy
        if params[:linked_entry]
          linked_entry = Entry.new(params[:linked_entry])
          linked_entry = copy_to_linked_entry(@entry, linked_entry)
          @entry.linked_entry = linked_entry
        end
      end
      
      @linked_entry = @entry.linked_entry
    end

    respond_to do |format|
      # Próba aktualizacji wpisu
      begin
        update_success = @entry.update_attributes(entry_params)
      rescue => e
        # Obsługa błędów podczas aktualizacji
        Rails.logger.error("Błąd podczas aktualizacji wpisu: #{e.message}")
        update_success = false
        @entry.errors.add(:base, "Wystąpił błąd podczas zapisywania: #{e.message}")
      end
      
      # Sprawdź, czy aktualizacja się powiodła
      if update_success
        # Sprawdź czy zmienił się typ wpisu
        if original_is_expense != @entry.is_expense
          flash[:notice] = "Zmiany zapisane. Zmieniono typ wpisu z #{original_is_expense ? 'wydatku' : 'wpływu'} na #{@entry.is_expense ? 'wydatek' : 'wpływ'}."
        else
          flash[:notice] = "Zmiany zapisane"
        end
        
        # Wyczyść informację o zmianie typu z sesji
        session[:entry_type_changed] = nil
        
        format.html do
          # Zawsze wracaj do strony, z której przyszedł użytkownik (referer),
          # a jeśli referer nie istnieje, wróć do widoku książki
          redirect_destination = if @referer.present?
            @referer
          else
            journal_path(@journal)
          end
          
          redirect_to redirect_destination
        end
        format.json { head :ok }
      else
        # W przypadku błędu walidacji, przygotuj formularz do ponownego wyświetlenia
        @categories = Category.where(:year => @entry.journal.year, :is_expense => @entry.is_expense)
        create_empty_items(@entry, @journal.year)
        @sorted_items = @entry.items.sort_by {|item| item.category.position.to_s}

        format.html { render action: "edit" }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /entries/1
  # DELETE /entries/1.json
  def destroy
    @entry = Entry.find(params[:id])
    authorize! :destroy, @entry
    journal = @entry.journal
    @entry.destroy

    respond_to do |format|
      format.html { redirect_to journal_url(journal) }
      format.json { head :ok }
    end
  end

  def create_empty_items_in_linked_entry(entry)
    return nil unless entry
    
    if entry.linked_entry
      linked_entry = entry.linked_entry
    else
      linked_entry = Entry.new(:is_expense => !entry.is_expense)
      linked_entry.items = []
      linked_entry.is_expense = !entry.is_expense
    end
    
    # Upewnij się, że linked_entry ma prawidłowy typ (przeciwny do głównego wpisu)
    if linked_entry.is_expense == entry.is_expense
      linked_entry.is_expense = !entry.is_expense
    end
    
    create_empty_items(linked_entry, entry.journal.year)

    return linked_entry
  end

  def create_empty_items(entry, year)
    # Sprawdź czy wymagane pola są ustawione
    return if entry.nil? || year.nil?
    
    # Najpierw czyścimy istniejące items, gdy zmieniamy typ wpisu
    if params[:type_changed].present?
      entry.items = []
    end
    
    # Pobierz wszystkie kategorie pasujące do typu wpisu i roku
    begin
      categories = Category.where(:year => year, :is_expense => entry.is_expense)
      
      # Dodajemy nowe items dla odpowiednich kategorii
      categories.each do |category|
        unless entry.has_category(category)
          new_item = Item.new(:category_id => category.id)
          # Ustaw domyślne wartości dla nowego item
          new_item.amount = 0
          new_item.amount_one_percent = 0 if category.is_expense
          entry.items << new_item
        end
      end
    rescue => e
      # Loguj błąd, ale nie przerywaj wykonania
      Rails.logger.error("Błąd podczas tworzenia pustych items: #{e.message}")
    end
  end

  def copy_to_linked_entry(entry, linked_entry)
    return nil unless entry && linked_entry
  
    # Kopiujemy podstawowe dane z głównego wpisu
    linked_entry.date = entry.date
    linked_entry.name = entry.name
    
    # Upewniamy się, że linked_entry ma zawsze przeciwny typ do głównego wpisu
    linked_entry.is_expense = !entry.is_expense
    
    # Kopiujemy document_number zawsze
    linked_entry.document_number = entry.document_number
    
    # Kopiujemy statement_number tylko jeśli to księga bankowa
    if entry.journal && entry.journal.journal_type_id == JournalType::BANK_TYPE_ID
      linked_entry.statement_number = entry.statement_number
    end
    
    # Upewnij się, że linked_entry ma prawidłowy journal_id, jeśli nie został jeszcze ustawiony
    if linked_entry.journal_id.blank? && entry.journal
      # Znajdź domyślny journal o przeciwnym typie
      other_journals = entry.journal.journals_for_linked_entry
      linked_entry.journal_id = other_journals.first.id if other_journals.any?
    end
    
    return linked_entry
  end

  private

  def entry_params
    if params[:entry]
      params.require(:entry).permit(:date, :name, :document_number, :statement_number, :journal_id, :is_expense, :linked_entry,
                                    :items_attributes => [:id, :amount, :amount_one_percent, :category_id, :grant_id,
                                      :item_grants_attributes => [:id, :amount, :grant_id, :item_id]])
    end
  end
end
