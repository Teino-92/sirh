module ApplicationHelper
  # Returns true if the current organization is on the full SIRH plan.
  def sirh_plan?
    current_employee&.organization&.sirh?
  end

  # Returns true for both manager_os and sirh plans.
  def manager_os_plan?
    current_employee&.organization&.plan&.in?(%w[manager_os sirh])
  end

  def status_badge_class(status)
    case status
    when 'pending'
      'bg-yellow-100 dark:bg-yellow-800 text-yellow-800 dark:text-yellow-200'
    when 'approved', 'auto_approved'
      'bg-green-100 dark:bg-green-800 text-green-800 dark:text-green-200'
    when 'rejected'
      'bg-red-100 dark:bg-red-800 text-red-800 dark:text-red-200'
    when 'cancelled'
      'bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200'
    else
      'bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200'
    end
  end

  def status_label(status)
    case status
    when 'pending'
      'En attente'
    when 'approved'
      'Approuvé'
    when 'auto_approved'
      'Auto-approuvé'
    when 'rejected'
      'Refusé'
    when 'cancelled'
      'Annulé'
    else
      status.titleize
    end
  end

  def leave_type_bg_class(leave_type)
    case leave_type
    when 'CP'
      'bg-blue-50 dark:bg-blue-900 border border-blue-200 dark:border-blue-700'
    when 'RTT'
      'bg-purple-50 dark:bg-purple-900 border border-purple-200 dark:border-purple-700'
    when 'Maladie'
      'bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-700'
    when 'Maternite', 'Paternite'
      'bg-pink-50 dark:bg-pink-900 border border-pink-200 dark:border-pink-700'
    else
      'bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700'
    end
  end

  def leave_type_text_class(leave_type)
    case leave_type
    when 'CP'
      'text-blue-700 dark:text-blue-300'
    when 'RTT'
      'text-purple-700 dark:text-purple-300'
    when 'Maladie'
      'text-red-700 dark:text-red-300'
    when 'Maternite', 'Paternite'
      'text-pink-700 dark:text-pink-300'
    else
      'text-gray-700 dark:text-gray-300'
    end
  end
end
