# Testing Checklist - Easy-RH

## Pre-Test Setup ✅
- [x] Database reset and seeded
- [x] All models have required scopes
- [x] All controllers load data correctly
- [x] Routes configured
- [x] Tailwind CSS built

## Test Accounts
```
Employee:
  Email: julien.petit@techcorp.fr
  Password: password123

Manager:
  Email: thomas.martin@techcorp.fr
  Password: password123

HR Admin:
  Email: admin@techcorp.fr
  Password: password123
```

## Employee Features to Test

### 1. Dashboard (/)
- [ ] Shows personalized greeting with employee name
- [ ] Displays current date in French
- [ ] Shows leave balances (CP, RTT, etc.)
- [ ] Displays weekly hours with progress bar
- [ ] Shows "Pointer l'entrée" button if not clocked in
- [ ] Shows "Pointer la sortie" button if clocked in
- [ ] Shows upcoming leaves (if any)
- [ ] Shows pending requests (if any)

### 2. Time Tracking (/time_entries)
- [ ] Click "Pointer l'entrée" - should create time entry
- [ ] Redirects to dashboard with success message
- [ ] Button changes to "Pointer la sortie"
- [ ] Live duration shows on dashboard
- [ ] Visit /time_entries to see history
- [ ] Filter by "Cette semaine" and "Ce mois-ci"
- [ ] Desktop: Shows full table
- [ ] Mobile: Shows card layout
- [ ] Click "Pointer la sortie" - completes entry
- [ ] Duration calculated correctly

### 3. Leave Requests (/leave_requests)
- [ ] Click "Mes congés" in navigation
- [ ] Shows current leave balances at top
- [ ] Filter tabs work: All / À venir / Historique
- [ ] Click "Nouvelle demande"
- [ ] Form shows:
  - [ ] Type selector (CP, RTT, etc.)
  - [ ] Start date and end date pickers
  - [ ] Half-day options (AM/PM)
  - [ ] Reason field (optional)
  - [ ] Available balances displayed
  - [ ] Info about auto-approval rules
- [ ] Submit leave request
- [ ] Shows success message
- [ ] Status badge shows correctly:
  - Yellow "En attente" for pending
  - Green "Auto-approuvé" if auto-approved (≤2 days with ≥15 days balance)
- [ ] Can cancel pending requests

## Manager Features to Test

### 4. Manager Dashboard (login as thomas.martin@techcorp.fr)
- [ ] Dashboard shows "Action requise" card if pending approvals
- [ ] Shows count of pending approvals
- [ ] "Équipe" tab visible in navigation (mobile bottom, desktop top)
- [ ] Can see team members' info

### 5. Pending Approvals (/leave_requests/pending_approvals)
- [ ] Click "Voir les demandes" or "Équipe" tab
- [ ] Shows pending requests count
- [ ] Shows approved this month count
- [ ] Each request shows:
  - [ ] Employee name and department
  - [ ] Leave type and dates
  - [ ] Duration (days count)
  - [ ] Current balance for that leave type
  - [ ] Warning if balance insufficient
  - [ ] Employee's reason (if provided)
- [ ] Click "Approuver" button
  - [ ] Shows confirmation
  - [ ] Request approved
  - [ ] Balance deducted automatically
- [ ] Click "Refuser" button
  - [ ] Shows confirmation prompt
  - [ ] Request rejected

## Responsive Design Tests

### Mobile (< 640px)
- [ ] Bottom navigation visible
- [ ] Top navigation hidden
- [ ] Cards layout for time entries
- [ ] Cards layout for leave requests
- [ ] Large touch targets (buttons)
- [ ] Forms are single-column
- [ ] Date pickers work on mobile

### Desktop (≥ 640px)
- [ ] Top navigation visible
- [ ] Bottom navigation hidden
- [ ] Tables show full data
- [ ] Multi-column layouts
- [ ] Hover states work

## PWA Features

### Installation
- [ ] Visit on Chrome/Safari mobile
- [ ] "Install app" prompt appears
- [ ] Install to home screen
- [ ] App icon appears
- [ ] Opens in standalone mode (no browser chrome)

### App Shortcuts (long-press icon on Android/iOS)
- [ ] "Pointer l'arrivée" shortcut
- [ ] "Demander un congé" shortcut

### Offline (optional - basic caching)
- [ ] Disconnect network
- [ ] Previously visited pages load from cache
- [ ] Shows offline message for new pages

## Data Validation Tests

### Time Entries
- [ ] Cannot clock in if already clocked in (shows error)
- [ ] Cannot clock out if not clocked in (shows error)
- [ ] Duration calculated correctly
- [ ] Weekly/monthly summaries accurate

### Leave Requests
- [ ] Cannot submit with end_date < start_date
- [ ] Shows error if insufficient balance
- [ ] Half-day requests calculate as 0.5 days
- [ ] Weekends excluded from working days count
- [ ] Auto-approval logic:
  - ✓ CP only (not other types)
  - ✓ ≤2 days
  - ✓ Balance ≥15 days
  - ✓ Otherwise goes to manager

### Manager Actions
- [ ] Only managers can access /leave_requests/pending_approvals
- [ ] Non-managers redirected with error
- [ ] Manager can only see their team's requests
- [ ] Approval updates balance immediately

## French Localization
- [ ] All dates in French format (DD/MM/YYYY)
- [ ] French day names (lundi, mardi, etc.)
- [ ] French month names (janvier, février, etc.)
- [ ] All UI text in French
- [ ] Status labels in French (En attente, Approuvé, etc.)

## Performance Checks
- [ ] Dashboard loads in <1s
- [ ] Navigation is instant (Turbo)
- [ ] Forms submit quickly
- [ ] No console errors
- [ ] No N+1 queries (check rails logs)

## Known Issues to Track
- [ ] Module autoloading for LeaveManagement::Services (RTT accrual disabled)
- [ ] API authentication (JWT) not implemented
- [ ] Pundit policies not enforced
- [ ] Background jobs not implemented
- [ ] Email notifications not implemented
- [ ] Team calendar view not implemented

## Success Criteria
✅ Employee can clock in/out
✅ Employee can view time history
✅ Employee can request leave
✅ Auto-approval works for eligible requests
✅ Manager can approve/reject requests
✅ Balances update automatically
✅ Mobile-responsive design works
✅ PWA installable on mobile

---

## How to Run Tests

1. Start the server:
```bash
bin/dev
```

2. Visit: http://localhost:3000

3. Login with test accounts above

4. Go through each section and check off items

5. Report any issues found
