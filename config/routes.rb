Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Logowanie kontem UKE (WSO2, SAML). Adres /users/saml/auth jest zarejestrowany w WSO2 – nie zmieniać.
  devise_for :users, controllers: { saml_sessions: "users/saml_sessions" }
  # Logowanie bez WSO2 – tylko w środowisku development (lokalnie nie ma dostępu do IdP).
  post "dev/login" => "development_sessions#create", as: :development_login if Rails.env.development?

  # Adresy z prefiksem języka jak w poprzedniej wersji (linki w wysłanych mailach: /pl/proposals/…).
  scope "/:locale", locale: /pl/, defaults: { locale: "pl" } do
    resources :proposals, param: :multi_app_identifier, only: %i[index show create destroy] do
      member do
        patch :annul
        get :testportal
      end
      resources :wizard, only: %i[show update], controller: "proposals/steps"
    end
    resource :privacy_consent, only: %i[show create]
    get "lookups/addresses" => "lookups#addresses", as: :address_lookup
    get "declaration" => "pages#declaration"
    get "static_pages/declaration" => redirect("/pl/declaration")
    get "static_pages/home" => redirect("/pl")
    root "pages#home", as: :home
  end
  root to: redirect("/pl", status: 302)

  # API dla NETPAR: token, zmiana statusu zgłoszenia oraz odczyt zgód RODO i historii (Netpar: EgzaminyUser, EgzaminyProposal).
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      get :token, to: "base#token"
      resources :proposals, param: :multi_app_identifier, only: %i[show update]
    end
  end
end
