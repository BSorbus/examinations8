# Logowanie bez WSO2 – tylko w development (trasa istnieje tylko w tym środowisku).
# Tworzy użytkownika z danymi jak z konta UKE, aby można było przejść cały kreator lokalnie.
class DevelopmentSessionsController < ApplicationController
  before_action { head :not_found unless Rails.env.development? }

  def create
    user = User.find_or_create_by!(email: params.fetch(:email, "test.egzaminy@example.com").downcase) do |u|
      u.first_name, u.last_name, u.family_name = "Jan", "Testowy", "Testowy"
      u.birth_date, u.birth_city, u.pesel = Date.new(1990, 1, 1), "Gdynia", "90010100009"
    end
    sign_in(user)
    redirect_to proposals_path
  end
end
