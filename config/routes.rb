require 'sidekiq/web'
Rails.application.routes.draw do
  # Mount letter_opener_web for development
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: '/letter_opener'
  end

  namespace :admin do
    authenticate :admin do
      mount Sidekiq::Web => '/sidekiq'
    end
    get '/', to: 'dashboard#index', as: :admin_root
    get 'dashboard', to: 'dashboard#index', as: :dashboard
    resources :products do
      collection do
        post :destroy_selected
        post :upload_image
        post :upload_video
      end
      member do
        get :variants
        post :revert
      end
      resources :product_variants, only: [:index]
    end
    resources :blogs do
      collection do
        post :upload_image
        post :upload_video
        post :destroy_selected
      end
    end
    resources :customers do
      collection do
        post :destroy_selected
        patch :bulk_update_status
      end
      member do
        post :send_password_reset
      end
    end
    resources :admins, except: [:show] do
      member do
        post :send_password_reset
      end
    end
    resources :brands
    resources :related_categories do
      collection do
        post :destroy_selected
        post :bulk_update_weight
      end
    end
    resources :promotions do
      collection { post :destroy_selected }
      resources :promotion_usages, only: [:index, :show]
    end
    resources :hero_banners do
      collection do
        post :destroy_selected
      end
    end
    resources :promotion_usages, only: [:index, :show]
    resources :system_configs, only: %i[index show edit update]
    resources :categories
    resources :collections, except: [:show]
    resources :menus
    resources :menu_bar_items do
      collection do
        patch :sort
      end
      member do
        post :move_subtree
      end
    end


    # Unified selector endpoints for TomSelect
    resource :selectors, only: [], controller: 'selectors' do
      collection do
        get :categories
        get :brands
        get :product_collections
        get :products
      end
    end
    resources :redirection_mappings, except: [:show] do
      collection do
        post :destroy_selected
      end
    end
    resources :orders, only: [:index, :show] do
      member do
        patch :update_status
      end
      collection do
        get :export
      end
    end
    resources :payment_transactions, only: [:index, :show]

    resource :product_data_transfer, only: [], controller: 'product_data_transfer' do
      collection do
        get :export
        post :generate_export
        post :export_recent
        get :import
        post :process_import
        get :import_progress
      end
    end
  end

  mount RailsAdmin::Engine => '/sadmin', as: 'rails_admin'
  devise_for :admins,
    controllers: {
      sessions: 'admins/sessions',
      registrations: 'admins/registrations',
      passwords: 'admins/passwords',
      confirmations: 'admins/confirmations',
      unlocks: 'admins/unlocks'
    }

  # Configure Devise routes for users (skip web controllers since we're using API)
  devise_for :users, skip: [:sessions, :registrations, :passwords, :confirmations, :unlocks]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  namespace :api do
    resources :auth, only: [] do
      collection do
        post :sign_in
        post :sign_up
        post :refresh_token
        post :log_out
        post :log_out_all_devices
        post :forgot_password
        post :reset_password
        post :verify_reset_password_token
      end
    end

    resources :cart_sessions, param: :session_id, only: [] do
      collection do
        post :create
      end
      member do
        get :validate
      end
    end

    resources :carts, only: [:index, :show, :create, :update, :destroy] do
      collection do
        post :add_item
        post :add_bundle
        put :update_item
        delete :remove_item
        post :apply_promotion
        post :claim
        post :email
        post :merge
        put :update_guest_email
        get 'shared/:access_token', action: :shared, as: :shared
      end
    end
    # OnePay Payment Gateway Integration Routes
    # -------------------------------------------
    # This is the endpoint that OnePay will send a webhook to after a transaction.
    match '/payments/onepay_callback', to: 'payments#onepay_callback', via: [:get, :post]
    # Get available installment options for a payment amount
    get '/payments/installment_options', to: 'payments#installment_options'
    # Order endpoints
    post '/checkout', to: 'orders#create'
    resources :orders, only: [:index, :show] do
      collection do
        get :search_by_number
      end
    end


    resources :blogs, only: [:index, :show], param: :slug do
      collection do
        get :search
        get :categories
      end
      member do
        post :view_count
      end
    end

    resources :collections, only: [:index, :show], param: :slug
    resources :brands, only: [:index, :show], param: :slug
    resources :blog_categories, only: [:index, :show], param: :slug
    resources :categories, only: [:index, :show], param: :slug do
      collection do
        get :related_products
      end
    end
    resources :subscribers, only: [:create]
    resource :user, only: [:update] do
      collection do
        get :profile
      end
    end
    resources :redirection_mappings, only: [:index]

    get :global, controller: :static, action: :global
    get :menu_bar, controller: :static, action: :menu_bar
    get :landing_page, controller: :static, action: :landing_page
    get :search_items, controller: :static, action: :search_items

    namespace :seo do
      get :products, to: 'sitemap#products'
      get :categories, to: 'sitemap#categories'
      get :collections, to: 'sitemap#collections'
      get :brands, to: 'sitemap#brands'
      get :blogs, to: 'sitemap#blogs'
      get :menu_items, to: 'sitemap#menu_items'
      get :paginated_products, to: 'paginated_products#index', as: :paginated_products
    end

    match '/query(/*path)', to: 'query#perform', via: :all
    get '/product/:slug', controller: 'product', action: :show
  end
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
