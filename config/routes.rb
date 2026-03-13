Rails.application.routes.draw do
  # Devise authentication
  devise_for :employees, skip: [:registrations], controllers: { passwords: 'devise/passwords' }

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root path — Landing for guests, Dashboard for authenticated
  root to: 'pages#home'

  # Trial expired (accessible even after trial expiry)
  get '/trial-expire', to: 'trial_expired#show', as: :trial_expired

  # Stripe webhooks (no auth, raw body required)
  post '/webhooks/stripe', to: 'stripe_webhooks#create', as: :stripe_webhooks

  # Billing & subscription management
  resource :billing, only: [:show] do
    post   :create_checkout
    get    :success
    post   :upgrade
    post   :request_upgrade
    delete :cancel
  end

  authenticated :employee do
    root to: 'dashboard#show', as: :authenticated_root
  end

  # Trial registration (public)
  resource :trial_registration, only: [:create]

  # Legal pages (public)
  get '/cgu',                          to: 'pages#cgu',                          as: :cgu
  get '/politique-de-confidentialite', to: 'pages#politique_de_confidentialite', as: :politique_de_confidentialite
  get '/mentions-legales',             to: 'pages#mentions_legales',             as: :mentions_legales

  # Web UI - Responsive (works great on mobile AND desktop)
  resource :dashboard, only: [:show], controller: 'dashboard'
  resource :profile, only: [:show, :edit, :update], controller: 'profile' do
    patch :dashboard_layout, on: :member
  end

  resources :time_entries, only: [:index] do
    collection do
      post :clock_in
      post :clock_out
    end
  end

  resources :leave_requests do
    member do
      post :approve
      get :reject_form
      post :reject
      post :cancel
    end

    collection do
      get :pending_approvals
      get :team_calendar
    end
  end

  resources :leave_balances, only: [:index]
  resources :work_schedules, only: [:show, :edit, :update]
  resources :objectives, only: [:index, :show]
  resources :one_on_ones, only: [:index, :show]
  resources :evaluations, only: [:index, :show] do
    member do
      patch :submit_self_review
    end
  end
  resources :action_items, only: [:index] do
    member do
      patch :complete
    end
  end

  resources :training_assignments, only: [:index, :show] do
    member do
      patch :complete
    end
  end

  resources :employee_onboardings, only: [:show]

  resources :trial_period_decisions, only: [] do
    member do
      post :confirm
      post :renew
      post :terminate
    end
  end

  resources :notifications, only: [:index] do
    member do
      post :mark_as_read
    end
    collection do
      post :mark_all_as_read
    end
  end

  # Manager-specific routes
  namespace :manager do
    get :dashboard
    resources :objectives do
      member do
        patch :complete
      end
    end
    resources :one_on_ones do
      member do
        patch :complete
      end
    end
    resources :action_items, only: [:update]
    resources :evaluations do
      member do
        patch :complete
        patch :submit_manager_review
        patch :launch
      end
    end
    resources :trainings do
      member do
        patch :archive
        patch :unarchive
      end
    end

    resources :team_members do
      resource :work_schedule, only: [:new, :create, :edit, :update]
      resources :weekly_schedule_plans
      resources :time_entries, only: [:index] do
        collection do
          post :validate_week
        end
        member do
          post :validate_entry
          post :reject_entry
        end
      end
    end
    get 'team_schedules', to: 'team_schedules#index'

    # Employee Onboarding
    resources :employee_onboardings do
      resources :employee_onboarding_tasks,   only: [:update], shallow: true
      resources :employee_onboarding_reviews, only: [:new, :create], shallow: true
    end

    # CSV Exports
    resources :exports, only: [:index] do
      collection do
        get  :time_entries,   to: 'exports#time_entries'
        get  :absences,       to: 'exports#absences'
        post :search,         to: 'exports#search'
        get  :search_export,  to: 'exports#search_export'
      end
    end
  end

  # API v1 - For future native mobile apps
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'login', to: 'sessions#create'
      post 'refresh', to: 'sessions#refresh'
      delete 'logout', to: 'sessions#destroy'

      # Dashboard - single endpoint for mobile app homepage
      get 'me/dashboard', to: 'dashboard#show'

      # Time tracking
      resources :time_entries, only: [:index, :show] do
        collection do
          post :clock_in
          post :clock_out
        end
      end

      # Leave management
      resources :leave_requests, only: [:index, :create] do
        member do
          patch :approve
          patch :reject
        end

        collection do
          get :pending_approvals
          get :team_calendar
        end
      end

      # Leave balances (read-only for employees)
      resources :leave_balances, only: [:index]

      # Work schedules
      resources :work_schedules, only: [:show, :update]

      # Payroll — HR/Admin only
      scope :payroll do
        get  'employees',     to: 'payroll#employees',      as: :payroll_employees
        get  'employees/:id', to: 'payroll#employee_detail', as: :payroll_employee
        get  'summary',       to: 'payroll#summary',        as: :payroll_summary
      end

      # Team management (managers only)
      namespace :team do
        resources :employees, only: [:index, :show]
        get :overview, to: 'overview#show'
      end
    end
  end

  # Admin panel - Hotwire-based
  namespace :admin do
    root to: 'employees#index'
    resources :employees
    resource :organization, only: [:show, :edit, :update]
    resources :onboarding_templates do
      resources :onboarding_template_tasks, only: [:new, :create, :edit, :update, :destroy],
                                            shallow: true
    end
    resource :group_policies, only: [:edit, :update] do
      collection do
        post :preview
      end
    end
    resource :payroll, only: [:show], controller: 'payroll' do
      collection do
        get  :export
        get  :export_silae
        post :push_silae
      end
      resources :payroll_periods, only: [:create, :destroy]
    end
    resource :hr_query, only: [:show, :create] do
      collection do
        get :export
      end
    end
    resource :audit_log, only: [:show], controller: 'audit_logs'
    resource :employee_import, only: [:new, :create]
  end
end
