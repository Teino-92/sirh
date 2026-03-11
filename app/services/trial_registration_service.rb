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

      # Send Devise reset password email — user sets their own password on first login
      token = employee.send_reset_password_instructions

      Result.new(true, employee, [])
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(false, nil, e.record.errors.full_messages)
  end
end
