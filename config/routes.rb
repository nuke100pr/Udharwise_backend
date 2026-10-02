Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      namespace :auth do
        post "otp/request", to: "otp#request_otp"
        post "otp/verify", to: "otp#verify"
        post "login", to: "sessions#create"
        post "signup", to: "registrations#create"
      end

      get "me", to: "users#me"
      patch "me", to: "users#update"
      put "me", to: "users#update"
      get "users/search", to: "users#search"

      resources :groups, only: [:index, :create, :show] do
        member do
          post :archive
          post :unarchive
          get :balances
          get :simplify
          get :members
          post :settle_all
        end
        resources :invites, only: [:index, :create], controller: "group_invites"
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

      resources :invites, only: [:index] do
        member do
          post :accept
          post :decline
        end
      end
    end
  end
end
