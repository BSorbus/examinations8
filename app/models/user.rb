# Użytkownik zalogowany kontem UKE (WSO2, SAML). Dane osobowe z konta służą do wypełnienia zgłoszenia.
class User < ApplicationRecord
  devise :saml_authenticatable, :trackable

  has_and_belongs_to_many :roles
  has_many :proposals, foreign_key: :creator_id, inverse_of: :creator
  has_many :privacy_consents, dependent: :delete_all

  before_save { email&.downcase! }
  after_create_commit { roles << Role.proposal_writer }

  def name = "#{first_name} #{last_name}"

  def privacy_accepted? = privacy_consents.exists?(version: PrivacyConsent.current_version)

  # Uprawnienia ze wszystkich ról użytkownika, np. "proposal:create_self".
  def activities
    @activities ||= roles.flat_map(&:activities).uniq
  end
end
