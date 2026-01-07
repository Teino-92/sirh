module ApplicationHelper
  def status_badge_class(status)
    case status
    when 'pending'
      'bg-yellow-100 text-yellow-800'
    when 'approved', 'auto_approved'
      'bg-green-100 text-green-800'
    when 'rejected'
      'bg-red-100 text-red-800'
    when 'cancelled'
      'bg-gray-100 text-gray-800'
    else
      'bg-gray-100 text-gray-800'
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
      'bg-blue-50 border border-blue-200'
    when 'RTT'
      'bg-purple-50 border border-purple-200'
    when 'Maladie'
      'bg-red-50 border border-red-200'
    when 'Maternite', 'Paternite'
      'bg-pink-50 border border-pink-200'
    else
      'bg-gray-50 border border-gray-200'
    end
  end

  def leave_type_text_class(leave_type)
    case leave_type
    when 'CP'
      'text-blue-700'
    when 'RTT'
      'text-purple-700'
    when 'Maladie'
      'text-red-700'
    when 'Maternite', 'Paternite'
      'text-pink-700'
    else
      'text-gray-700'
    end
  end
end
