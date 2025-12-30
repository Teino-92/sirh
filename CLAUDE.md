# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Easy-RH is a modern SIRH (HRIS) platform built for French companies, designed with a **manager-first** philosophy. Unlike legacy HR tools that serve HR departments, this platform empowers managers to handle time tracking, leave requests, and team scheduling autonomously.

**Core Differentiators:**
- **Hybrid Architecture**: Responsive web UI (mobile-first) + RESTful API for future native apps
- Mobile-first responsive design with Tailwind CSS and Hotwire/Turbo
- French labor law compliance engine (CP, RTT calculations)
- Auto-approval workflows for low-risk requests
- Domain-driven architecture
- Multi-tenant from day 1
- PWA support for app-like experience on mobile browsers

See `PROJECT_SUMMARY.md` for complete feature list and implementation details.

## Technology Stack

- **Ruby**: 3.3.5
- **Rails**: 7.1.6
- **Database**: PostgreSQL
- **CSS Framework**: Tailwind CSS (via cssbundling-rails)
- **JavaScript**: jsbundling-rails, Turbo, Stimulus
- **Authentication**: Devise
- **Authorization**: Pundit
- **Background Jobs**: Sidekiq
- **Web Server**: Puma

## Development Commands

### Starting the Application

Start the development server with hot-reloading for CSS:
```bash
bin/dev
```

This runs both the Rails server (port 3000) and watches Tailwind CSS for changes via foreman using `Procfile.dev`.

Alternatively, start Rails server only:
```bash
rails server
# or
bin/rails s
```

### Database Management

Create and setup the database:
```bash
rails db:create
rails db:migrate
rails db:seed
```

Reset the database:
```bash
rails db:reset
```

Run migrations:
```bash
rails db:migrate
```

Rollback last migration:
```bash
rails db:rollback
```

### Asset Pipeline

Build Tailwind CSS:
```bash
yarn build:css
```

Watch Tailwind CSS for changes:
```bash
yarn build:css --watch
```

### Rails Console

Access Rails console:
```bash
rails console
# or
rails c
```

### Code Generation

Generate a new model:
```bash
rails generate model ModelName field:type
```

Generate a new controller:
```bash
rails generate controller ControllerName action1 action2
```

Generate a migration:
```bash
rails generate migration MigrationName
```

### Routes

View all application routes:
```bash
rails routes
# or for specific pattern
rails routes | grep pattern
```

## Application Structure

### Domain-Driven Design
The application uses a hybrid architecture with domain-driven structure:

```
app/
├── domains/
│   ├── employees/models/          # Employee, roles, hierarchy
│   ├── time_tracking/             # TimeEntry, clock in/out
│   │   ├── models/
│   │   └── services/
│   ├── leave_management/          # LeaveBalance, LeaveRequest, French legal engine
│   │   ├── models/
│   │   └── services/
│   └── scheduling/                # WorkSchedule, templates
│       └── models/
├── controllers/                   # Web UI controllers (responsive)
│   ├── dashboard_controller.rb
│   ├── time_entries_controller.rb
│   ├── leave_requests_controller.rb
│   └── ...
├── api/v1/                        # API controllers (future native apps)
│   ├── dashboard_controller.rb
│   ├── time_entries_controller.rb
│   └── ...
├── views/                         # Responsive web UI views
│   ├── layouts/
│   │   └── application.html.erb  # Mobile bottom nav + desktop top nav
│   ├── dashboard/
│   ├── time_entries/
│   ├── leave_requests/
│   └── devise/
└── models/                        # Shared models (Organization)
```

**Key Domains:**
1. **Employees**: Authentication, authorization, manager hierarchy
2. **Time Tracking**: Clock in/out, time entries, RTT accrual
3. **Leave Management**: CP/RTT balances, leave requests, French legal compliance
4. **Scheduling**: Work schedules, shift planning, RTT eligibility

**User Interfaces:**
1. **Responsive Web UI**: Primary interface, works beautifully on mobile AND desktop
   - Mobile: Bottom navigation, touch-optimized, PWA support
   - Desktop: Top navigation, full tables, multi-column layouts
2. **RESTful API**: Future-ready for native mobile apps (iOS/Android)

### Module Name
The Rails application module is `EasyRh` (defined in config/application.rb:21).

### Business Logic Location

**French Legal Compliance Engine:**
- **Location:** `app/domains/leave_management/services/leave_policy_engine.rb`
- **Purpose:** Implements French labor law for leave management
- **Key Features:**
  - CP accrual: 2.5 days/month, max 30 days/year, expires May 31
  - RTT calculation: Based on hours over 35h/week
  - French holiday calendar (11 public holidays + Easter calculation)
  - Validation rules: minimum consecutive leave, balance checks
  - Auto-approval logic for low-risk requests

**Domain Models:**
- `Employee` - Devise authentication, roles (employee/manager/hr/admin), manager hierarchy
- `LeaveBalance` - Tracks CP, RTT, Maladie, Maternité, etc. per employee
- `LeaveRequest` - Workflow: pending → approved/rejected, auto-approve logic
- `TimeEntry` - Clock in/out, duration calc, 10h/day max (French law)
- `WorkSchedule` - Weekly pattern, RTT eligibility, template-based

### Routes

**Web UI Routes (Primary Interface):**
- `GET /dashboard` - Employee dashboard with clock in/out, leave balances, weekly hours
- `GET /time_entries` - Time tracking history (week/month view)
- `POST /time_entries/clock_in` - Clock in
- `POST /time_entries/clock_out` - Clock out
- `GET /leave_requests` - Employee's leave requests (with filters: all/upcoming/history)
- `GET /leave_requests/new` - Create new leave request
- `POST /leave_requests/:id/cancel` - Cancel pending request
- `GET /leave_requests/pending_approvals` - Manager: approve/reject requests
- `POST /leave_requests/:id/approve` - Manager: approve request
- `POST /leave_requests/:id/reject` - Manager: reject request
- `GET /leave_requests/team_calendar` - Manager: team calendar view

**API Endpoints (Future Native Apps):**
- `GET /api/v1/me/dashboard` - Single call returns: time entry, schedule, balances, team status
- `POST /api/v1/time_entries/clock_in` - Mobile clock in with geolocation
- `POST /api/v1/leave_requests` - Auto-approves if eligible
- `GET /api/v1/leave_requests/team_calendar` - Manager view with coverage analysis

See `config/routes.rb` for complete route definition.

### PWA Features

**Progressive Web App Support:**
- `manifest.json` - PWA manifest with app metadata, icons, theme colors
- Service worker (`public/service-worker.js`) - Offline support, caching strategy
- Installable on mobile home screen
- App shortcuts for quick clock in and leave requests
- Optimized for mobile browsers (Safari, Chrome)

**Mobile-First Responsive Design:**
- Bottom navigation on mobile, top navigation on desktop
- Touch-optimized buttons and forms
- Responsive tables (cards on mobile, full tables on desktop)
- Mobile date pickers and selectors

### Database Configuration
- Development DB: `easy_rh_development`
- Test DB: `easy_rh_test`
- Production DB: `easy_rh_production` (requires `EASY_RH_DATABASE_PASSWORD` env var)

### Asset Pipeline
- Tailwind CSS source: `app/assets/stylesheets/application.tailwind.css`
- Built CSS output: `app/assets/builds/application.css`
- CSS is built using Tailwind CLI via the `build:css` npm script

### Key Gems and Their Purposes
- **devise**: User authentication system (config in config/initializers/devise.rb)
- **pundit**: Authorization policies (likely in app/policies/)
- **sidekiq**: Background job processing with Redis
- **turbo-rails**: Hotwire's SPA-like navigation
- **stimulus-rails**: Lightweight JavaScript framework
- **jsbundling-rails**: JavaScript bundling
- **cssbundling-rails**: CSS bundling (using Tailwind)

### Rails Configuration
- System tests are disabled (config.generators.system_tests = nil)
- Active Storage is commented out (not currently used)
- Action Mailbox and Action Text are commented out (not currently used)
- Test Unit is commented out (no test framework configured yet)

## Important Notes

### ⚠️ Known Issues

1. **Module autoloading issue** with `LeaveManagement::Services` namespace
   - Temporary fix: RTT accrual callback disabled in `TimeEntry` model
   - Proper fix needed: Restructure `app/domains/` or configure Zeitwerk

2. **API authentication incomplete**
   - Devise configured for Employee model
   - Token-based auth (JWT) needed for mobile API
   - Current: `authenticate_employee!` placeholder in BaseController

3. **Pundit policies not implemented**
   - Gem added but no policy classes created
   - Authorization checks exist but not enforced

### Test Suite
No tests configured yet. Recommended: RSpec with FactoryBot for French legal compliance engine testing.

### Background Jobs
Sidekiq configured but jobs not implemented yet:
- Monthly CP accrual
- Weekly/monthly RTT accrual
- Leave expiration notifications
- Email notifications for approvals

### Seed Data
Run `rails db:seed` to create test accounts:
- HR Admin: `admin@techcorp.fr` / `password123`
- Manager: `thomas.martin@techcorp.fr` / `password123`
- Employee: `julien.petit@techcorp.fr` / `password123`

### Docker Support
Dockerfile present for containerization (deployment-ready).

## Development Workflow

### Adding a New Leave Type
1. Add to `LeaveBalance::LEAVE_TYPES` constant
2. Update `LeavePolicyEngine` validation rules if needed
3. Add localization in `config/locales/fr.yml`

### Adding a New API Endpoint
1. Create controller action in `app/api/v1/`
2. Add route in `config/routes.rb` under `namespace :api > namespace :v1`
3. Test with curl or Postman
4. Document in PROJECT_SUMMARY.md

### Debugging French Legal Logic
```ruby
rails console
employee = Employee.first
engine = LeaveManagement::Services::LeavePolicyEngine.new(employee)
engine.calculate_cp_balance # Test CP calculation
engine.calculate_working_days(Date.parse('2025-08-01'), Date.parse('2025-08-15'))
```
