# frozen_string_literal: true

class TrialRegistrationService
  Result = Struct.new(:success?, :employee, :errors)

  ALLOWED_PLANS = %w[manager_os sirh].freeze

  BILLING_MODEL_FOR_PLAN = {
    'manager_os' => 'per_team',
    'sirh'       => 'per_employee'
  }.freeze

  def initialize(params)
    @org_name   = params[:organization_name].to_s.strip
    @first_name = params[:first_name].to_s.strip
    @last_name  = params[:last_name].to_s.strip
    @email      = params[:email].to_s.strip.downcase
    @plan       = ALLOWED_PLANS.include?(params[:plan].to_s) ? params[:plan].to_s : "sirh"
  end

  def call
    employee = nil

    ActiveRecord::Base.transaction do
      org = Organization.create!(
        name:          @org_name,
        plan:          @plan,
        billing_model: BILLING_MODEL_FOR_PLAN[@plan],
        settings:      Organization.new.default_settings
      )

      employee = ActsAsTenant.with_tenant(org) do
        Employee.create!(
          organization:  org,
          first_name:    @first_name,
          last_name:     @last_name,
          email:         @email,
          password:      SecureRandom.hex(16),
          role:          'manager',
          contract_type: 'CDI',
          start_date:    Date.current
        )
      end
    end

    # Send reset password email — with tenant context to avoid validation issues
    ActsAsTenant.with_tenant(employee.organization) do
      raw_token, hashed_token = Devise.token_generator.generate(Employee, :reset_password_token)
      employee.update_columns(
        reset_password_token:   hashed_token,
        reset_password_sent_at: Time.current
      )
      Devise::Mailer.reset_password_instructions(employee, raw_token).deliver_now
    end

    Result.new(true, employee, [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(false, nil, e.record.errors.full_messages)
  rescue StandardError => e
    Rails.logger.error "[TrialRegistration] Email delivery failed: #{e.message}"
    Result.new(true, employee, [])
  end
end
