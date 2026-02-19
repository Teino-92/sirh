Rails.application.routes.draw do
  # Devise authentication
  devise_for :employees, skip: [:registrations]

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root path - Dashboard for authenticated, sign in for guests
  authenticated :employee do
    root to: 'dashboard#show', as: :authenticated_root
  end

  # Web UI - Responsive (works great on mobile AND desktop)
  resource :dashboard, only: [:show], controller: 'dashboard'
  resource :profile, only: [:show, :edit, :update], controller: 'profile'

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

    resources :team_members, only: [:index, :show] do
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

    # CSV Exports
    resources :exports, only: [:index] do
      collection do
        get :time_entries, to: 'exports#time_entries'
        get :absences, to: 'exports#absences'
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
  end

  # Default root for non-authenticated users
  root to: redirect('/employees/sign_in')
end
