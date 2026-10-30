# Akceptacja informacji o przetwarzaniu danych osobowych (RODO).
# Wersja treści – config/examinations.yml (privacy_version); jej zmiana wymaga ponownej akceptacji od wszystkich.
class PrivacyConsent < ApplicationRecord
  belongs_to :user

  validates :version, presence: true, uniqueness: { scope: :user_id }

  def self.current_version = Rails.configuration.x.examinations.fetch(:privacy_version).to_s
end
