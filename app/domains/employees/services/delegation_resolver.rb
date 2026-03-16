# frozen_string_literal: true

# Centralizes delegation logic: can this employee act under a given role
# via an active delegation?
class DelegationResolver
  def self.can_act_as?(employee, role)
    return true if employee.role == role || employee.admin?

    EmployeeDelegation.active_now.for_delegatee(employee).exists?(role: role)
  end

  # Returns all manager IDs whose role has been delegated to this employee.
  def self.delegated_manager_ids(employee, role: "manager")
    EmployeeDelegation.active_now.for_delegatee(employee).where(role: role).pluck(:delegator_id)
  end
end
