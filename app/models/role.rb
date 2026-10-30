# Rola z listą uprawnień (activities), jak w poprzedniej wersji.
class Role < ApplicationRecord
  has_and_belongs_to_many :users

  validates :name, presence: true, length: { in: 1..100 }, uniqueness: { case_sensitive: false }

  DEFAULTS = {
    "Administrator Ról Systemowych" => {
      activities: %w[role:index role:show role:create role:update role:delete role:work],
      note: "Rola służy do tworzenia, modyfikowania Ról. \r\n (Przypisz tylko zaawansowanym Administratorom systemu)"
    },
    "Administrator Użytkowników" => {
      activities: %w[user:index user:show user:create user:update user:delete role:add_remove_role_user user:work],
      note: "Rola służy do zarządzania Użytkownikami i przypisywania im Ról Systemowych. \r\n (Przypisz tylko zaawansowanym Administratorom systemu)"
    },
    "Administrator Zgłoszeń" => {
      activities: %w[proposal:index proposal:show proposal:create proposal:update proposal:delete proposal:work],
      note: "Rola służy do zarządzania Zgłoszeniami. \r\n (Przypisz tylko zaawansowanym Administratorom systemu)"
    },
    "Wypełniający Zgłoszenia" => {
      activities: %w[proposal:index_self proposal:show_self proposal:create_self proposal:update_self proposal:delete_self],
      note: "Rola pozwala wypełniać Zgłoszenia. \r\n (Przypisz Użytkownikom, którzy mają wypełnić ankietę)"
    }
  }.freeze

  def self.find_or_create_default(name)
    find_or_create_by!(name:) { it.assign_attributes(DEFAULTS.fetch(name)) }
  end

  # Rola nadawana każdemu nowemu użytkownikowi.
  def self.proposal_writer = find_or_create_default("Wypełniający Zgłoszenia")
end
