# frozen_string_literal: true

class TrialRegistrationService
  Result = Struct.new(:success?, :employee, :errors)

  def initialize(params)
    @org_name   = params[:organization_name].to_s.strip
    @first_name = params[:first_name].to_s.strip
    @last_name  = params[:last_name].to_s.strip
    @email      = params[:email].to_s.strip.downcase
    @password   = SecureRandom.hex(10)
  end

  def call
    ActiveRecord::Base.transaction do
      org = Organization.create!(
        name: @org_name,
        settings: Organization.new.default_settings
      )

      employee = ActsAsTenant.with_tenant(org) do
        Employee.create!(
          organization:  org,
          first_name:    @first_name,
          last_name:     @last_name,
          email:         @email,
          password:      @password,
          role:          'admin',
          contract_type: 'CDI',
          start_date:    Date.current
        )
      end

      TrialWelcomeMailer.welcome(employee, @password).deliver_later

      Result.new(true, employee, [])
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(false, nil, e.record.errors.full_messages)
  end
end
