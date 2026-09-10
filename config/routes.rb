Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: [:new, :create, :destroy]

  resources :subscriptions do
    resources :accounts
    resources :events
    resources :tags
  end

  resources :events do
    resources :tagged_items
    member do
      post :update
    end
  end

  resources :buckets do
    resources :events, only: [:index]
  end

  resources :accounts do
    resources :buckets
    resources :events, only: [:index]
    resources :statements
  end

  resources :tags do
    resources :events, only: [:index]
  end

  resources :tagged_items, only: [:create, :destroy]
  resources :statements

  root to: "subscriptions#index"
  get "change_password" => "accounts#change_password"
  post "change_password" => "accounts#change_password"
end
