class PagesController < ApplicationController
  # Deklaracja dostępności – dostępna zawsze (także przed akceptacją informacji o danych osobowych).
  skip_before_action :require_privacy_consent, only: :declaration
  def home
  end

  def declaration
  end
end
