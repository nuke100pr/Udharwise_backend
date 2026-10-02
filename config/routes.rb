Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api do
    namespace :v1 do
      namespace :auth do
        post "otp/request", to: "otp#request_otp"
        post "otp/verify", to: "otp#verify"
      end

      get "me", to: "users#me"

      resources :groups, only: [:index, :create] do
        member do
          post :archive
          post :unarchive
          get :balances
          get :simplify
        end
        resources :invites, only: [:create], controller: "group_invites"
        resources :expenses, only: [:index, :create] do
          member do
            post :archive
            post :unarchive
            post :settle_share
          end
        end
        resource :expenses_export, only: [:show], controller: "group_exports"
        resources :audit_logs, only: [:index] do
          collection do
            get :export
          end
        end
      end

      resources :invites, only: [] do
        member do
          post :accept
          post :decline
        end
      end

      get "users/search", to: "users#search"

    end
  end
end
