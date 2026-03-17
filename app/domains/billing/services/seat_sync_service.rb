# frozen_string_literal: true

# Syncs Stripe subscription seat quantity after employee creation/deactivation.
# Called OUTSIDE any DB transaction — Stripe is external, never roll back via DB.
#
# Usage:
#   SeatSyncService.new(organization).sync!
class SeatSyncService
  SEAT_PRICE_IDS = {
    'manager_os'     => ENV['STRIPE_MANAGER_OS_SEAT_PRICE_ID'],
    'sirh_essential' => ENV['STRIPE_SIRH_ESSENTIEL_SEAT_PRICE_ID'],
    'sirh_pro'       => ENV['STRIPE_SIRH_PRO_SEAT_PRICE_ID']
  }.freeze

  INCLUDED_SEATS = {
    'manager_os'     => 6,
    'sirh_essential' => 30,
    'sirh_pro'       => 50
  }.freeze

  def initialize(organization)
    @org = organization
  end

  def sync!
    return unless stripe_eligible?

    seat_price_id = SEAT_PRICE_IDS[@subscription.plan]
    return unless seat_price_id.present?

    included   = INCLUDED_SEATS.fetch(@subscription.plan, 0)
    active_count = ActsAsTenant.without_tenant { Employee.where(organization_id: @org.id).active.count }
    quantity   = [active_count - included, 0].max

    stripe_sub = Stripe::Subscription.retrieve(@subscription.stripe_subscription_id)
    seat_item  = stripe_sub.items.data.find { |i| i.price.id == seat_price_id }

    if seat_item
      Stripe::SubscriptionItem.update(seat_item.id, { quantity: quantity })
    else
      Stripe::SubscriptionItem.create({
        subscription: stripe_sub.id,
        price:        seat_price_id,
        quantity:     quantity,
        proration_behavior: 'always_invoice'
      })
    end

    Rails.logger.info "[SeatSyncService] #{@org.name} — plan=#{@subscription.plan} active=#{active_count} qty=#{quantity}"
  rescue Stripe::StripeError => e
    Rails.logger.error "[SeatSyncService] Stripe error for org #{@org.id}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  rescue => e
    Rails.logger.error "[SeatSyncService] Unexpected error for org #{@org.id}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end

  # Returns the extra seat count (above included quota) — used for UI display
  def extra_seats
    return 0 unless @subscription
    included     = INCLUDED_SEATS.fetch(@subscription.plan, 0)
    active_count = ActsAsTenant.without_tenant { Employee.where(organization_id: @org.id).active.count }
    [active_count - included, 0].max
  end

  # Returns what the next monthly charge will be after adding 1 seat
  def price_after_adding_one_seat
    return nil unless @subscription
    included     = INCLUDED_SEATS.fetch(@subscription.plan, 0)
    active_count = ActsAsTenant.without_tenant { Employee.where(organization_id: @org.id).active.count }
    new_extras   = [active_count + 1 - included, 0].max - [active_count - included, 0].max
    new_extras > 0 ? new_extras : 0
  end

  # True if adding one more employee will exceed the included quota
  def quota_exceeded?
    return false unless @subscription
    included     = INCLUDED_SEATS.fetch(@subscription.plan, 0)
    active_count = ActsAsTenant.without_tenant { Employee.where(organization_id: @org.id).active.count }
    active_count >= included
  end

  private

  def stripe_eligible?
    @subscription = ActsAsTenant.without_tenant { Subscription.find_by(organization_id: @org.id) }
    @subscription&.active? && @subscription&.stripe_subscription_id.present?
  end
end
