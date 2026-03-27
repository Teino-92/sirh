# Design Spec — Mobile UX & Planning Redesign

**Date:** 2026-03-27
**Status:** Approved
**Agents:** @architect (framing), @front (design), @developer (implementation)

---

## Context

Izi-RH is a Rails 7 SaaS SIRH targeting French SMEs. The audit identified two critical UX failures:

1. **Mobile navigation is broken** — the entire desktop nav is hidden on mobile (`hidden md:...`) with no replacement. Mobile users cannot navigate the app.
2. **Planning UX is too slow** — scheduling is form-based with manual text input (`09:00-17:00`) per day per employee. For 10 employees × 4 weeks, this requires dozens of form submissions.

Additionally, two production bugs were identified: dynamic Tailwind class generation (styles missing in prod) and touch targets below 44px minimum.

---

## Scope

This spec covers:

- Mobile navigation: hybrid drawer + quick actions
- Planning UX: team grid view + template-based assignment
- Two production bug fixes: dynamic Tailwind classes, touch targets

This spec does NOT cover:
- Dashboard GridStack mobile responsiveness (separate initiative)
- ViewComponent architecture migration
- Accessibility full audit pass

---

## Design Decisions

### Navigation Mobile — Hybrid Drawer + Quick Actions

**Pattern chosen:** Hybrid (drawer for full nav + contextual quick actions bar)

**Rationale:** Managers need full navigation access (drawer covers all cases) but also need 1-tap access to their most frequent actions. Role-aware quick actions eliminate friction for the most common daily gestures.

#### Structure

**Hamburger button** — added to the top navbar, left of the logo, mobile only (`md:hidden`):
- Icon: 3-line hamburger
- Size: `min-h-[44px] min-w-[44px]` (touch target compliance)
- Position: leftmost element in navbar on mobile

**Drawer** — slides in from the left on hamburger tap:
- Full-height overlay, width `w-72`
- Contains: logo + org name at top, then all nav links identical to desktop navbar (Dashboard, Pointage, Horaire, Congés, Équipe with sub-items expanded inline, Admin/RH)
- Active state highlighted (same indigo styling as desktop)
- Close: X button top-right of drawer + semi-transparent overlay click + Escape key
- Animation: `translate-x` transition via Tailwind (`transition-transform duration-200`)
- Implementation: Stimulus controller `mobile-nav`

**Quick actions bar** — fixed strip below the top navbar, mobile only (`md:hidden`):
- Height: `h-12` (48px — touch compliant)
- Background: white / dark:gray-800, border-bottom
- Content — role-aware:
  - **Always (manager):** `Approuver` pill (with pending count badge) + `Planning` pill
  - **If `!cadre?`:** + `Pointer` pill (clock in/out)
  - **Non-manager employees:** `Congés` + `Pointage` (if `!cadre?`)
- Pills: `rounded-full px-4 py-2 text-sm font-medium` with indigo accent for primary action
- Pending approvals badge: red dot with count, same logic as existing `unread_count` pattern

#### Stimulus Controller: `mobile_nav_controller.js`

Responsibilities:
- `open()` / `close()` — toggle drawer visibility via CSS class
- `toggle()` — hamburger button action
- `closeOnOverlay(event)` — click outside closes
- `closeOnEscape(event)` — keydown Escape closes
- Focus trap: on open, focus first nav link; on close, return focus to hamburger button

#### Files modified
- `app/views/layouts/application.html.erb` — add hamburger button, drawer markup, quick actions bar
- `app/javascript/controllers/mobile_nav_controller.js` — new Stimulus controller

#### Files unchanged
- Desktop navbar markup (`hidden md:...`) — untouched

---

### Planning UX — Team Grid + Template Assignment

**Pattern chosen:** Hybrid (team grid view for overview + template-based assignment, mobile-specific view)

**Rationale:** The current form-based UX requires one form per employee per week. The redesign eliminates manual text input entirely for 90% of cases (template-based), provides a team overview grid on desktop, and degrades gracefully to a per-employee list on mobile.

#### Desktop/Tablet View — Monthly Team Grid

**Location:** `app/views/manager/team_schedules/index.html.erb` (refactored)

**Layout:**
- Rows = team members (employee name + avatar initials)
- Columns = weeks of the selected month (4-5 weeks)
- Each cell = assigned template badge for that week, or empty "+" if unplanned
- Month navigation: `← Février | Mars 2026 | →` header

**Cell states:**
- Assigned: colored badge matching template (indigo = Standard, purple = Décalé, green = Temps partiel, gray = Repos, orange = Congé)
- Unplanned: dashed border + `+` icon, tap/click opens assignment modal
- Mixed week (some days differ): `Mixte` badge in amber

**Assignment modal (Turbo Frame `schedule_cell`):**
- Opens inline on cell click (no full page reload)
- Lists available templates as selectable cards (reuses existing `@schedule_templates`)
- "Personnalisé" option → expands to show per-day time inputs (current form, preserved)
- "Appliquer à tout le mois" checkbox for bulk assignment
- "Copier semaine précédente" button per row (applies previous week's template to current week)
- Submit closes modal, updates cell via Turbo Stream

**Stimulus controller:** `schedule-grid`
- Manages cell selection state
- Handles modal open/close
- Handles "copy previous week" action

#### Mobile View — 2-Week Rolling per Employee

**Location:** same `index.html.erb`, conditional on mobile via `sm:hidden` / `hidden sm:block`

**Layout:**
- List of team members (cards, same style as existing member cards)
- Tap on a member → expands (Turbo Frame or Stimulus toggle) to show next 14 days
- Each day: pill showing day label + date + assigned template (or "Non planifié")
- Tap on a day pill → same template assignment modal (adapted for small screen, bottom sheet style)
- No text input exposed — template selection only (Personnalisé hidden behind "Options avancées" disclosure)

#### Schedule Edit Form — Template-First

**Location:** `app/views/manager/weekly_schedule_plans/edit.html.erb` (refactored)

**Changes:**
- Remove 7 × text input rows (`09:00-17:00` free text)
- Replace with: template selection cards grid (already exists in the form, kept and promoted to primary interaction)
- Template selection now sets the schedule and submits — no per-day editing required for standard cases
- "Personnalisé" option reveals the per-day inputs (current form) for atypical schedules
- Keep notes field, week display, error messages unchanged

**No model changes required** — `WeeklySchedulePlan#schedule_pattern` JSONB field preserved. Templates map to the same pattern format.

---

## Production Bug Fixes

### Fix 1 — Dynamic Tailwind Classes

**File:** `app/views/time_entries/index.html.erb` lines 65–70

**Problem:** `bg-<%= banner_color %>-50` and `text-<%= banner_color %>-800` — Tailwind JIT cannot detect dynamic class fragments. These classes are absent from the compiled CSS in production.

**Solution:** Replace with a complete-class lookup map in the controller or a view helper:

```ruby
# In controller or helper:
BANNER_CLASSES = {
  "yellow"  => "bg-yellow-50 text-yellow-800 border-yellow-200",
  "red"     => "bg-red-50 text-red-800 border-red-200",
  "blue"    => "bg-blue-50 text-blue-800 border-blue-200",
  "green"   => "bg-green-50 text-green-800 border-green-200",
  "gray"    => "bg-gray-50 text-gray-800 border-gray-200",
}.freeze

# In view:
# class="<%= BANNER_CLASSES[banner_color] %>"
```

All class strings are now static and detectable by Tailwind JIT.

### Fix 2 — Touch Targets

**Problem:** Many interactive elements below Apple's 44px minimum tap target guideline.

**Specific fixes:**
- Notification bell: `p-2` → `p-2.5` + wrap in `min-h-[44px] min-w-[44px] flex items-center justify-center`
- Dark mode toggle: same treatment
- Quick actions bar pills: built with `py-2.5 px-4 min-h-[44px]` from the start
- Hamburger button: `min-h-[44px] min-w-[44px]`

---

## Acceptance Criteria

### Mobile Navigation
- [ ] On mobile (< 768px): hamburger button visible and tappable (≥ 44px)
- [ ] Drawer opens on tap, contains all nav links visible on desktop
- [ ] Drawer closes on overlay click, X button, and Escape key
- [ ] Quick actions bar visible below navbar on mobile
- [ ] Manager sees: Approuver (with badge count) + Planning
- [ ] Non-cadre manager also sees: Pointer
- [ ] Non-manager employee sees role-appropriate quick actions
- [ ] Desktop navbar unchanged — zero regression
- [ ] Dark mode works in drawer and quick actions bar

### Planning Grid
- [ ] Desktop: monthly team grid renders with template badges per cell
- [ ] Desktop: clicking a cell opens template assignment modal without full reload
- [ ] Desktop: "Appliquer à tout le mois" applies template to all weeks
- [ ] Desktop: "Copier semaine précédente" works per row
- [ ] Mobile: 2-week rolling view per employee renders correctly
- [ ] Mobile: template assignment works via bottom-sheet style modal
- [ ] No free-text time input required for standard template assignment
- [ ] "Personnalisé" option still available and functional
- [ ] No model/database schema changes

### Bug Fixes
- [ ] Banner colors in time_entries render correctly in production (no dynamic class fragments)
- [ ] Notification bell, dark mode toggle, and all new interactive elements meet 44px touch target

---

## Non-Goals

- No drag-and-drop (deferred — requires significant JS, out of scope for this sprint)
- No React or any JS framework introduction
- No ViewComponent migration
- No changes to WeeklySchedulePlan data model
- No changes to template definitions (managed via existing `@schedule_templates`)

---

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Drawer focus trap regression on desktop | Low | Stimulus controller scoped to mobile breakpoint check |
| Template assignment modal breaking existing edit flow | Medium | Personnalisé option preserves current form exactly |
| Turbo Frame modal on mobile (bottom sheet) layout issues | Medium | Fallback to full-page navigation if modal layout breaks |
| Quick actions bar pushing content down on small phones | Low | `h-12` fixed, content area gets `pt-12` compensation |

---

## Implementation Order

1. **Fix dynamic Tailwind classes** (hotfix, no design risk)
2. **Mobile navigation** (hamburger + drawer + quick actions bar)
3. **Planning grid desktop** (team grid + template modal)
4. **Planning mobile view** (2-week rolling, per-employee)
5. **Schedule edit form** (template-first, hide text inputs)
6. **Touch target fixes** (sweep during step 2)
