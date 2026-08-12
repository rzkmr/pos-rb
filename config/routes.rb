Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session, only: [ :new, :create, :destroy ]
  resources :devices, only: [ :index, :create, :destroy ] do
    collection do
      get :pair
    end
  end

  resources :dining_tables, only: [ :index ]
  resources :table_sessions, only: [ :create, :show ] do
    resource :bill, only: [ :show ], controller: "bills"
    resources :payments, only: [ :create ]
    resource :discount, only: [ :create ], controller: "discounts"
  end
  resources :tickets, only: [ :create ]
  resources :invoices, only: [] do
    member { post :reprint }
  end
  resources :ticket_items, only: [] do
    member { patch :void }
  end
  resources :kitchen_tickets, only: [ :index, :update ]
  get "heartbeat" => "heartbeats#show"

  # Defines the root path route ("/")
  root "dining_tables#index"
end
