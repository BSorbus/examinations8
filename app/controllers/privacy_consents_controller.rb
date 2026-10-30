# Informacja o przetwarzaniu danych osobowych (RODO) po zalogowaniu. „Akceptuję” – zapis (wersja, czas, IP)
# i powrót do żądanej strony; „Nie akceptuję” – zwykłe wylogowanie (także z WSO2), bez zapisu.
class PrivacyConsentsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :require_privacy_consent

  def show
    redirect_to after_sign_in_path_for(current_user) if current_user.privacy_accepted?
  end

  def create
    current_user.privacy_consents.find_or_create_by!(version: PrivacyConsent.current_version) do |consent|
      consent.accepted_at = Time.current
      consent.ip = request.remote_ip
    end
    redirect_to after_sign_in_path_for(current_user), status: :see_other
  end
end
