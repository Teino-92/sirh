# frozen_string_literal: true

if defined?(Bullet)
  Bullet.enable = true
  Bullet.alert = false
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true

  # False positives : Bullet signale des eager loads inutilisés quand la
  # collection est vide — les associations sont bien accédées en vue quand non vide.
  Bullet.add_safelist type: :unused_eager_loading, class_name: "LeaveRequest",        association: :employee
  Bullet.add_safelist type: :unused_eager_loading, class_name: "EmployeeOnboarding",  association: :onboarding_tasks
  Bullet.add_safelist type: :unused_eager_loading, class_name: "OneOnOne",            association: :manager
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Employee",            association: :work_schedule
end
