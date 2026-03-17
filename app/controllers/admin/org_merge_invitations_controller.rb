# frozen_string_literal: true

module Admin
  class OrgMergeInvitationsController < BaseController
    before_action :set_invitation, only: [:destroy]

    def index
      @invitations = policy_scope(OrgMergeInvitation)
                       .includes(:source_organization, :invited_by)
                       .order(created_at: :desc)
      authorize OrgMergeInvitation
    end

    def new
      @invitation = OrgMergeInvitation.new
      authorize @invitation
    end

    def create
      authorize OrgMergeInvitation

      source_employee = ActsAsTenant.without_tenant do
        Employee.find_by(email: params[:invited_email])
      end
      source_org = source_employee&.organization

      if source_org.nil?
        redirect_to new_admin_org_merge_invitation_path,
          alert: "Aucun compte trouvé pour cet email." and return
      end

      if source_org.id == current_organization.id
        redirect_to new_admin_org_merge_invitation_path,
          alert: "Vous ne pouvez pas fusionner votre propre organisation." and return
      end

      @invitation = OrgMergeInvitation.new(
        target_organization: current_organization,
        source_organization: source_org,
        invited_email:       params[:invited_email],
        invited_by:          current_employee
      )

      if @invitation.save
        acceptance_url = org_merge_acceptance_url(
          token: @invitation.token,
          host:  ENV.fetch('APP_HOST', 'izi-rh.com'),
          protocol: 'https'
        )
        OrgMergeMailerService.new(invitation: @invitation).send_invitation(acceptance_url)
        redirect_to admin_org_merge_invitations_path,
          notice: "Invitation envoyée à #{@invitation.invited_email}."
      else
        flash.now[:alert] = @invitation.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @invitation
      @invitation.update!(status: 'declined')
      redirect_to admin_org_merge_invitations_path,
        notice: "Invitation annulée."
    end

    private

    def set_invitation
      @invitation = policy_scope(OrgMergeInvitation).find(params[:id])
    end
  end
end
