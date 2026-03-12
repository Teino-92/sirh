# frozen_string_literal: true

class TrialExpiredController < ApplicationController
  skip_before_action :check_trial_expired!

  def show
    redirect_to root_path unless employee_signed_in?
  end
end
