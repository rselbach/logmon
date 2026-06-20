Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#index"

  get "/login", to: "sessions#new", as: :login
  get "/auth/github/callback", to: "sessions#callback", as: :github_callback
  match "/auth/apple/callback", to: "sessions#apple_callback", via: [:get, :post], as: :apple_callback
  get "/auth/failure", to: "sessions#failure", as: :auth_failure
  delete "/logout", to: "sessions#destroy", as: :logout

  resources :access_logs, only: %i[index show]
  resources :error_logs, only: %i[index show]
end
