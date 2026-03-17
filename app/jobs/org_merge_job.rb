# frozen_string_literal: true

class OrgMergeJob < ApplicationJob
  queue_as :default

  def perform(invitation_id)
    invitation = OrgMergeInvitation.find_by(id: invitation_id)
    return unless invitation
    return if invitation.status.in?(%w[merging completed])

    # Atomic guard against race condition — only one job proceeds
    updated = OrgMergeInvitation.where(id: invitation_id, status: 'accepted')
                                 .update_all(status: 'merging')
    return if updated == 0

    invitation.reload

    result = OrgMergeService.new(invitation: invitation).call

    unless result.success
      invitation.update(
        status: 'failed',
        merge_log: invitation.merge_log.merge('errors' => result.errors)
      )
    end
  rescue => e
    Rails.logger.error "[OrgMergeJob] #{e.message}"
    OrgMergeInvitation.find_by(id: invitation_id)&.update(status: 'failed')
    raise
  end
end
