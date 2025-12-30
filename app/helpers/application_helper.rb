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
end
