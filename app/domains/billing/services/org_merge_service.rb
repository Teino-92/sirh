# frozen_string_literal: true

class OrgMergeService
  Result = Struct.new(:success, :errors, :stats, keyword_init: true)

  # Modèles avec organization_id, dans l'ordre des dépendances FK
  # (les parents avant les enfants)
  MIGRATABLE_MODELS = %w[
    BusinessRule
    OnboardingTemplate
    OnboardingTemplateTask
    WorkSchedule
    WeeklySchedulePlan
    LeaveBalance
    LeaveRequest
    TimeEntry
    OneOnOne
    ActionItem
    Objective
    Training
    TrainingAssignment
    EmployeeOnboarding
    OnboardingTask
    OnboardingReview
    Evaluation
    EvaluationObjective
    Notification
    ApprovalStep
    RuleExecution
    EmployeeDelegation
    PayrollPeriod
  ].freeze

  def initialize(invitation:)
    @invitation = invitation
    @source_org = invitation.source_organization
    @target_org = invitation.target_organization
    @stats      = {}
    @errors     = []
  end

  def call
    ActiveRecord::Base.transaction do
      ActsAsTenant.without_tenant do
        @source_org.with_lock do
          validate_preconditions!
          check_no_email_duplicates!
          migrate_employees
          migrate_org_scoped_models
          dissolve_source_org
          @invitation.update!(
            status: 'completed',
            completed_at: Time.current,
            merge_log: @stats
          )
        end
      end
    end

    cancel_source_stripe_subscription
    notify_target_admin

    Result.new(success: true, errors: [], stats: @stats)
  rescue StandardError => e
    Rails.logger.error "[OrgMergeService] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    Sentry.capture_exception(e) if defined?(Sentry)
    Result.new(success: false, errors: [e.message], stats: @stats)
  end

  private

  def validate_preconditions!
    raise "Invitation non acceptable (status: #{@invitation.status})" unless @invitation.status.in?(%w[accepted merging])
    raise "Organisation source déjà fusionnée" if @source_org.status == 'merged'
    raise "Organisation target invalide (doit être SIRH)" unless @target_org.sirh?
  end

  def check_no_email_duplicates!
    source_emails = Employee.where(organization_id: @source_org.id).pluck(:email)
    target_emails = Employee.where(organization_id: @target_org.id).pluck(:email)
    duplicates    = source_emails & target_emails

    if duplicates.any?
      raise "Emails en double détectés entre les deux organisations : #{duplicates.join(', ')}. Résolvez ces conflits avant de fusionner."
    end
  end

  def migrate_employees
    count = Employee.where(organization_id: @source_org.id)
                    .update_all(organization_id: @target_org.id)
    @stats['employees'] = count
  end

  def migrate_org_scoped_models
    MIGRATABLE_MODELS.each do |model_name|
      model = model_name.constantize
      next unless model.column_names.include?('organization_id')

      count = model.where(organization_id: @source_org.id)
                   .update_all(organization_id: @target_org.id)
      @stats[model.table_name] = count
    rescue NameError
      Rails.logger.warn "[OrgMergeService] Modèle inconnu ignoré: #{model_name}"
    end
  end

  def dissolve_source_org
    @source_org.update_columns(
      status: 'merged',
      merged_into_id: @target_org.id,
      merged_at: Time.current
    )
  end

  def cancel_source_stripe_subscription
    sub = ActsAsTenant.without_tenant { Subscription.find_by(organization_id: @source_org.id) }
    return unless sub&.stripe_subscription_id.present?

    Stripe::Subscription.cancel(sub.stripe_subscription_id)
    sub.update_columns(status: 'canceled')
  rescue Stripe::StripeError => e
    Rails.logger.error "[OrgMergeService] Stripe cancel failed: #{e.message}"
    @stats['stripe_error'] = e.message
  end

  def notify_target_admin
    admin = ActsAsTenant.without_tenant do
      Employee.where(organization_id: @target_org.id)
              .find_by(id: @invitation.invited_by_id)
    end
    return unless admin

    OrgMergeMailerService.new(invitation: @invitation).send_completion_notification(admin.email)
  rescue => e
    Rails.logger.error "[OrgMergeService] Notification failed: #{e.message}"
  end
end
