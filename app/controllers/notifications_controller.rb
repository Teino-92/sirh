# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :authenticate_employee!

  def index
    @notifications = policy_scope(Notification).recent.limit(50)
    @unread_count = current_employee.notifications.unread.count
  end

  def mark_as_read
    @notification = current_employee.notifications.find(params[:id])
    authorize @notification
    @notification.mark_as_read!

    # Redirect based on notification type
    redirect_to notification_redirect_path(@notification)
  end

  def mark_all_as_read
    authorize Notification
    current_employee.notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: 'Toutes les notifications ont été marquées comme lues'
  end

  private

  def notification_redirect_path(notification)
    case notification.notification_type
    when 'schedule_created', 'schedule_updated'
      work_schedule_path(current_employee.id)
    when 'leave_approved', 'leave_rejected'
      leave_requests_path
    when 'hours_validated', 'hours_rejected'
      time_entries_path
    else
      notifications_path
    end
  end
end
