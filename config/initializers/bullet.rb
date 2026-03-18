# frozen_string_literal: true

if defined?(Bullet)
  Bullet.enable = true
  Bullet.alert = false
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true

  # False positive : @absences_today peut être vide (0 absent aujourd'hui)
  # leave.employee est bien utilisé dans cards/_absences_today mais Bullet
  # ne le voit pas quand la collection est vide.
  Bullet.add_safelist type: :unused_eager_loading, class_name: "LeaveRequest", association: :employee
end
