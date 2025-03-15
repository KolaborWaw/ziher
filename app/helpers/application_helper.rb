module ApplicationHelper
  def menu_active?(section=nil)
    active = false
    case section
    when :journal_finance
      active = controller.controller_name == 'journals' && controller.action_name == 'default' && params[:journal_type_id] == JournalType::FINANCE_TYPE_ID.to_s
    when :journal_bank
      active = controller.controller_name == 'journals' && controller.action_name == 'default' && params[:journal_type_id] == JournalType::BANK_TYPE_ID.to_s
    when :journal_inventory
      active = controller.controller_name == 'journals' && controller.action_name == 'default' && params[:journal_type_id] == JournalType::INVENTORY_TYPE_ID.to_s
    when :units
      active = controller.controller_name == 'units' && controller.action_name == 'index'
    when :bank_accounts
      active = controller.controller_name == 'bank_accounts'
    else
      active = false
    end
    active ? 'active' : ''
  end

  def render_boolean_icon(value)
    return value ?
        "<span class='glyphicon glyphicon-ok'></span>".html_safe :
        "<i class='glyphicon glyphicon-minus'></i>".html_safe
  end

  def render_boolean_icon_centered(value)
    return ("<div class='text-center'>" + render_boolean_icon(value) + "</div>").html_safe
  end

  include Pagy::Frontend

  # Formatuje numer konta bankowego w standardowym formacie z odstępami
  def format_bank_account(account_number)
    return "" if account_number.blank?
    
    # Usuń wszystkie istniejące spacje i inne znaki specjalne
    clean_number = account_number.to_s.gsub(/\s+/, "").gsub(/[^0-9]/, "")
    
    # Formatuj numer konta: pierwsze 2 cyfry oddzielnie, a potem grupy po 4 cyfry
    if clean_number.length >= 2
      first_part = clean_number[0..1]
      rest = clean_number[2..-1]
      rest_formatted = rest.scan(/.{1,4}/).join(" ")
      formatted = "#{first_part} #{rest_formatted}"
    else
      formatted = clean_number
    end
    
    return formatted
  end

end
