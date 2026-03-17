# frozen_string_literal: true

class OrgMergeAcceptancesController < ApplicationController
  # Public endpoint — no authentication required (accessed via email link with token)
  skip_before_action :authenticate_employee!, raise: false
  skip_before_action :check_trial_expired!, raise: false

  def show
    @invitation = find_invitation_by_token
    return render_not_found unless @invitation

    unless @invitation.acceptable? || @invitation.status.in?(%w[merging completed failed])
      return render_not_found
    end

    if @invitation.acceptable?
      @preview_items = OrgMergePreviewService.new(
        source_organization: @invitation.source_organization
      ).call
    end
  end

  def update
    @invitation = find_invitation_by_token
    return render_not_found unless @invitation

    if params[:accept].present?
      unless @invitation.acceptable?
        redirect_to org_merge_acceptance_path(@invitation.token),
          alert: "Cette invitation ne peut plus être acceptée (statut: #{@invitation.status})." and return
      end

      updated = OrgMergeInvitation.where(id: @invitation.id, status: 'pending')
                                   .update_all(status: 'accepted', accepted_at: Time.current)

      if updated == 0
        redirect_to org_merge_acceptance_path(@invitation.token),
          alert: "Cette invitation a déjà été traitée." and return
      end

      OrgMergeJob.perform_later(@invitation.id)
      redirect_to org_merge_acceptance_path(@invitation.token),
        notice: "Migration acceptée ! Le processus de fusion a démarré."
    elsif params[:decline].present?
      unless @invitation.acceptable?
        redirect_to org_merge_acceptance_path(@invitation.token),
          alert: "Cette invitation ne peut plus être modifiée." and return
      end

      @invitation.update!(status: 'declined')
      redirect_to root_path, notice: "Vous avez décliné l'invitation de fusion."
    else
      redirect_to org_merge_acceptance_path(@invitation.token)
    end
  end

  private

  def find_invitation_by_token
    ActsAsTenant.without_tenant do
      OrgMergeInvitation.find_by(token: params[:token])
    end
  end

  def render_not_found
    render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
  end
end
