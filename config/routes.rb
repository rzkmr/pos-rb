Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Home-screen install: manifest + service worker (assets + the state-free
  # /offline_shell route only — see CLAUDE.md invariant #4).
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :setup, only: [ :new, :create ], controller: "setup" do
    get :done
  end
  resource :session, only: [ :new, :create, :destroy ]
  resources :devices, only: [ :index, :create, :destroy ] do
    collection do
      get :pair
    end
  end

  resources :dining_tables, only: [ :index ] do
    resources :held_carts, only: [ :index, :create ]
  end
  resources :held_carts, only: [ :destroy ]
  get "takeaway" => "takeaway_orders#current"
  resources :takeaway_orders, only: [ :show ]
  resources :table_sessions, only: [ :create, :show ] do
    resource :bill, only: [ :show ], controller: "bills"
    resources :payments, only: [ :create ]
    resource :discount, only: [ :create ], controller: "discounts"
  end
  resources :tickets, only: [ :create ]
  resources :takeaway_checkouts, only: [ :create ]
  resources :invoices, only: [] do
    member { post :reprint }
  end
  resources :ticket_items, only: [] do
    member { patch :void }
  end
  resources :kitchen_tickets, only: [ :index, :update ]
  get "heartbeat" => "heartbeats#show"
  patch "locale" => "locales#update"
  get "catalog_snapshot" => "catalog_snapshots#show"
  get "offline_shell" => "offline_shells#show"
  namespace :sync do
    resources :actions, only: [ :create ]
    resources :invoices, only: [ :create ]
    resource :invoice_authority, only: [ :create, :destroy ], controller: "invoice_authority"
  end

  # Token-authenticated API for an external client — see API-SPEC.md.
  # Deliberately separate from the cookie/session-based routes above,
  # which serve the in-browser PWA.
  namespace :api do
    namespace :v1 do
      get "health" => "health#show"
      get "bootstrap" => "bootstrap#show"
      get "delta" => "delta#show"
      get "updates" => "updates#show"
      namespace :owner do
        post "login" => "sessions#create"
        delete "logout" => "sessions#destroy"
      end
      namespace :devices do
        post "pair" => "pairings#create"
      end
      namespace :sync do
        post "batch" => "batch#create"
      end
    end
  end

  namespace :admin do
    resource :session, only: [ :new, :create, :destroy ]
    root "root#show"
    resources :menu_items, except: [ :show ]
    resources :users, except: [ :show ]
    resources :dining_tables, except: [ :show ]
    resource :sales, only: [ :show ], controller: "sales"
    resource :settings, only: [ :edit, :update ], controller: "settings"
    resources :invoice_authority_grants, only: [ :index ] do
      member { post :force_release }
    end
  end

  # Defines the root path route ("/")
  root "dining_tables#index"
end
