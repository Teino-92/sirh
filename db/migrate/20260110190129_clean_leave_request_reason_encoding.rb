# frozen_string_literal: true

class CleanLeaveRequestReasonEncoding < ActiveRecord::Migration[7.1]
  def up
    # Clean up double-encoded JSON strings in reason and rejection_reason fields
    LeaveRequest.find_each do |leave_request|
      # Clean reason field
      if leave_request.reason.present? && leave_request.reason.start_with?('\"')
        begin
          # Try to parse as JSON to unescape
          cleaned_reason = JSON.parse(leave_request.reason)
          leave_request.update_column(:reason, cleaned_reason)
        rescue JSON::ParserError
          # If it fails, just remove the escaped quotes manually
          cleaned_reason = leave_request.reason.gsub(/\A"|"\z/, '').gsub('\"', '"')
          leave_request.update_column(:reason, cleaned_reason)
        end
      end

      # Clean rejection_reason field
      if leave_request.rejection_reason.present? && leave_request.rejection_reason.start_with?('\"')
        begin
          cleaned_rejection = JSON.parse(leave_request.rejection_reason)
          leave_request.update_column(:rejection_reason, cleaned_rejection)
        rescue JSON::ParserError
          cleaned_rejection = leave_request.rejection_reason.gsub(/\A"|"\z/, '').gsub('\"', '"')
          leave_request.update_column(:rejection_reason, cleaned_rejection)
        end
      end
    end
  end

  def down
    # No need to revert - this is a data cleanup migration
  end
end
