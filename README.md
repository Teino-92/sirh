# Easy-RH: The Manager's Best Friend

A modern SIRH (HRIS) platform built for French companies. Manager-first, mobile-first, with French labor law compliance baked in.

## 🚀 Quick Start

```bash
# Install dependencies
bundle install
yarn install

# Setup database
rails db:create db:migrate db:seed

# Start the server
bin/dev
```

**Test accounts** (password: `password123`):
- HR Admin: `admin@techcorp.fr`
- Manager: `thomas.martin@techcorp.fr`
- Employee: `julien.petit@techcorp.fr`

## 📚 Documentation

- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Complete feature list, architecture, known issues, and next steps
- **[CLAUDE.md](CLAUDE.md)** - Development guide for working with this codebase
- **API Routes:** Run `rails routes | grep api` to see all endpoints

## 🎯 What Makes This Different

1. **Manager-centric** - HR tools serve managers, not just HR departments
2. **Mobile-first API** - Built for mobile from day 1
3. **French legal compliance engine** - CP, RTT calculations automated per French law
4. **Auto-approval workflows** - Managers only see edge cases
5. **Domain-driven architecture** - Clean, modular, ready to scale

## 🏗️ Architecture

```
app/
├── domains/              # Business logic by domain
│   ├── employees/
│   ├── time_tracking/
│   ├── leave_management/ # 🔥 French legal compliance engine
│   └── scheduling/
└── api/v1/              # Mobile-first API
```

## 🔑 Core Features

- ✅ Multi-tenant foundation
- ✅ Time tracking (clock in/out, overtime detection)
- ✅ Leave management (CP, RTT, auto-accrual)
- ✅ French legal compliance (holidays, working days, accrual rules)
- ✅ Manager approvals with auto-approve logic
- ✅ Work schedules & shift planning
- ✅ Mobile-optimized API endpoints

## 📊 API Endpoints

```bash
# Dashboard (single call for mobile homepage)
GET /api/v1/me/dashboard

# Time tracking
POST /api/v1/time_entries/clock_in
POST /api/v1/time_entries/clock_out

# Leave management
POST /api/v1/leave_requests
GET /api/v1/leave_requests/pending_approvals
PATCH /api/v1/leave_requests/:id/approve
```

See `config/routes.rb` for complete API definition.

## ⚙️ Tech Stack

- **Ruby:** 3.3.5
- **Rails:** 7.1.6
- **Database:** PostgreSQL
- **Authentication:** Devise
- **CSS:** Tailwind
- **Background Jobs:** Sidekiq (configured, jobs not implemented yet)

## ⚠️ Known Issues

1. Module autoloading issue with `LeaveManagement::Services` - needs Zeitwerk configuration
2. API authentication incomplete - token-based auth (JWT) needed for mobile
3. Pundit policies not implemented - authorization checks exist but not enforced

See [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) for complete issue list and fixes.

## 🚧 Next Steps

1. Fix module autoloading for domain services
2. Implement JWT for API authentication
3. Add Pundit authorization policies
4. Build admin panel (Hotwire)
5. Implement background jobs (CP/RTT accrual)
6. Write tests for French legal engine
7. Build mobile app (React Native/Flutter)

See [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) for detailed roadmap.

## 📞 Development

Built with [Claude Code](https://claude.com/claude-code) - December 2025

For development guidance, see [CLAUDE.md](CLAUDE.md).
