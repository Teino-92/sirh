# frozen_string_literal: true

class ObjectivesController < ApplicationController
  before_action :authenticate_employee!

  def index
    @objectives = policy_scope(Objective)
                   .for_owner(current_employee)
                   .order(deadline: :asc)

    if params[:status].present? && Objective.statuses.key?(params[:status])
      @objectives = @objectives.where(status: params[:status])
    end
  end

  def show
    @objective = policy_scope(Objective).find(params[:id])
    authorize @objective
  end
end
