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

    unless seat_price_id.present?
      Rails.logger.error "[SeatSyncService] Missing SEAT_PRICE_ID for plan=#{@subscription.plan} org=#{@org.id}"
      Sentry.capture_message("[SeatSyncService] Missing seat price ID for plan #{@subscription.plan}") if defined?(Sentry)
      return
    end

    included  = INCLUDED_SEATS.fetch(@subscription.plan, 0)
    quantity  = [active_seat_count - included, 0].max

    stripe_sub = Stripe::Subscription.retrieve(@subscription.stripe_subscription_id)
    seat_item  = stripe_sub.items.data.find { |i| i.price.id == seat_price_id }

    if seat_item
      Stripe::SubscriptionItem.update(seat_item.id, { quantity: quantity })
    elsif quantity > 0
      # Only create the seat item when there are actual overages — avoids zero-amount invoices
      Stripe::SubscriptionItem.create({
        subscription:       stripe_sub.id,
        price:              seat_price_id,
        quantity:           quantity,
        proration_behavior: 'always_invoice'
      })
    end

    Rails.logger.info "[SeatSyncService] #{@org.name} — plan=#{@subscription.plan} active=#{active_seat_count} qty=#{quantity}"
  rescue Stripe::StripeError => e
    Rails.logger.error "[SeatSyncService] Stripe error for org #{@org.id}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
    raise # re-raise so the job adapter retries
  rescue => e
    Rails.logger.error "[SeatSyncService] Unexpected error for org #{@org.id}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
    raise
  end

  # True if adding one more employee will exceed the included quota
  def quota_exceeded?
    stripe_eligible?
    return false unless @subscription

    included = INCLUDED_SEATS.fetch(@subscription.plan, 0)
    active_seat_count >= included
  end

  private

  def active_seat_count
    @active_seat_count ||= ActsAsTenant.without_tenant do
      Employee.where(organization_id: @org.id).active.count
    end
  end

  def stripe_eligible?
    @subscription ||= ActsAsTenant.without_tenant { Subscription.find_by(organization_id: @org.id) }
    @subscription&.active? && @subscription&.stripe_subscription_id.present?
  end
end
