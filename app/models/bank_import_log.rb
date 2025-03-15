class BankImportLog < ApplicationRecord
  belongs_to :user
  belongs_to :unit
  
  validates :user_id, :unit_id, :file_name, presence: true
  
  # Serializacja tablicy błędów
  serialize :error_messages, Array
  
  # Domyślne sortowanie - najnowsze na górze
  default_scope { order(created_at: :desc) }
  
  # Metoda tworząca nowy log importu
  def self.create_import_log(params)
    create(
      user_id: params[:user_id],
      unit_id: params[:unit_id],
      file_name: params[:file_name],
      account_number: params[:account_number],
      year: params[:year],
      success_count: params[:success_count] || 0,
      error_count: params[:error_count] || 0,
      error_messages: params[:error_messages] || [],
      ip_address: params[:ip_address],
      import_date: Time.now
    )
  end
  
  # Metoda dodająca błędy do istniejącego logu
  def add_errors(errors, count = 1)
    self.error_messages = (self.error_messages || []) + Array(errors)
    self.error_count += count
    save
  end
  
  # Metoda zwiększająca licznik udanych importów
  def add_success(count = 1)
    self.success_count += count
    save
  end
  
  # Metoda formatująca wiadomości o błędach do wyświetlenia
  def formatted_errors
    return "" if error_messages.blank?
    error_messages.join("; ")
  end
  
  # Metoda sprawdzająca czy import był całkowicie udany
  def successful?
    error_count == 0 && success_count > 0
  end
  
  # Metoda sprawdzająca czy import był częściowo udany
  def partially_successful?
    error_count > 0 && success_count > 0
  end
  
  # Metoda sprawdzająca czy import całkowicie się nie powiódł
  def failed?
    success_count == 0
  end
end 