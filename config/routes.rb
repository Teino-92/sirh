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

  resources :time_entries, only: [:index] do
    collection do
      post :clock_in
      post :clock_out
    end
  end

  resources :leave_requests do
    member do
      post :approve
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

  # Manager-specific routes
  namespace :manager do
    get :dashboard
    resources :team_members, only: [:index, :show]
  end

  # API v1 - For future native mobile apps
  namespace :api do
    namespace :v1 do
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

  # Admin panel (future - Hotwire-based)
  # namespace :admin do
  #   resources :organizations
  #   resources :employees
  # end

  # Default root for non-authenticated users
  root to: redirect('/employees/sign_in')
end
