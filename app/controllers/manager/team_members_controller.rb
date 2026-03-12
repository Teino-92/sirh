# frozen_string_literal: true

module Manager
  class TeamMembersController < BaseController
    before_action :set_team_member, only: [:show, :edit, :update, :destroy]

    def index
      @team_members = current_organization.employees
                        .where(manager_id: current_employee.id)
                        .order(:first_name, :last_name)
    end

    def show; end

    def new
      @team_member = Employee.new(
        organization: current_organization,
        manager:      current_employee,
        role:         'employee',
        contract_type: 'CDI',
        start_date:   Date.current
      )
      authorize @team_member, policy_class: Manager::TeamMemberPolicy
    end

    def create
      @team_member = Employee.new(team_member_params.merge(
        organization: current_organization,
        manager:      current_employee,
        role:         'employee'
      ))
      authorize @team_member, policy_class: Manager::TeamMemberPolicy

      @team_member.password = SecureRandom.hex(12)
      @team_member.password_confirmation = @team_member.password

      if @team_member.save
        send_invitation_email(@team_member)
        redirect_to manager_team_schedules_path,
          notice: "#{@team_member.full_name} a été ajouté. Un email d'invitation lui a été envoyé."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @team_member.update(team_member_update_params)
        redirect_to manager_team_schedules_path, notice: "#{@team_member.full_name} a été mis à jour."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if has_active_linked_data?(@team_member)
        redirect_to manager_team_schedules_path,
          alert: "Impossible de supprimer #{@team_member.full_name} : il/elle a des données actives liées (onboarding, congés en cours, ou pointages récents)."
        return
      end

      @team_member.destroy
      redirect_to manager_team_schedules_path, notice: "#{@team_member.full_name} a été supprimé."
    end

    private

    def set_team_member
      @team_member = current_organization.employees
                       .where(manager_id: current_employee.id)
                       .find(params[:id])
      authorize @team_member, policy_class: Manager::TeamMemberPolicy
    end

    def send_invitation_email(member)
      raw_token, hashed_token = Devise.token_generator.generate(Employee, :reset_password_token)
      member.update_columns(
        reset_password_token:   hashed_token,
        reset_password_sent_at: Time.current
      )

      reset_url = Rails.application.routes.url_helpers.edit_employee_password_url(
        reset_password_token: raw_token,
        host:                 ENV.fetch('APP_HOST', 'izi-rh.com'),
        protocol:             'https'
      )

      conn = Faraday.new('https://api.resend.com') do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      response = conn.post('/emails') do |req|
        req.headers['Authorization'] = "Bearer #{ENV['SMTP_PASSWORD']}"
        req.headers['Content-Type']  = 'application/json'
        req.body = {
          from:    "Izi-RH <noreply@#{ENV.fetch('SMTP_DOMAIN', 'izi-rh.com')}>",
          to:      [member.email],
          subject: "#{current_employee.full_name} vous invite sur Izi-RH",
          html:    <<~HTML
            <p>Bonjour #{member.first_name},</p>
            <p>#{current_employee.full_name} vous a ajouté à son équipe sur Izi-RH.</p>
            <p>Cliquez sur le lien ci-dessous pour créer votre mot de passe et accéder à votre espace :</p>
            <p><a href="#{reset_url}" style="background:#4F46E5;color:white;padding:12px 24px;border-radius:6px;text-decoration:none;display:inline-block;">Rejoindre l'équipe</a></p>
            <p>Ce lien est valable 6 heures.</p>
            <p>— L'équipe Izi-RH</p>
          HTML
        }
      end

      unless response.success?
        Rails.logger.error "[TeamMembers] Invitation email failed for #{member.email}: #{response.status} #{response.body}"
      end
    end

    def has_active_linked_data?(member)
      member.employee_onboardings.where(status: 'active').exists? ||
        member.leave_requests.where(status: %w[pending approved auto_approved]).exists? ||
        member.time_entries.where('clock_in >= ?', 30.days.ago).exists?
    end

    def team_member_params
      params.require(:employee).permit(
        :first_name, :last_name, :email,
        :job_title, :department,
        :contract_type, :start_date, :end_date
      )
    end

    def team_member_update_params
      params.require(:employee).permit(
        :first_name, :last_name, :email,
        :job_title, :department,
        :contract_type, :start_date, :end_date
      )
    end
  end
end
