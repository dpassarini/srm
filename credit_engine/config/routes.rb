Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Redirect /swagger and /api-docs to the Swagger UI page
  get "swagger", to: redirect("/swagger/index.html")
  get "api-docs", to: redirect("/swagger/index.html")

  namespace :api do
    namespace :v1 do
      resources :currencies, only: [ :index ]
      resources :receivable_types, only: [ :index ]
      resources :exchange_rates, only: [ :index, :create ]
      resources :operations, only: [ :index, :create ] do
        collection do
          post :simulate
        end
      end
      resources :settlement_reports, only: [ :index, :create ] do
        member do
          get :download
        end
      end
    end
  end
end
