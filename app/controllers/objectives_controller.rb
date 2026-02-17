# frozen_string_literal: true

class ObjectivesController < ApplicationController
  before_action :authenticate_employee!

  def index
    @objectives = policy_scope(Objective)
                   .for_owner(current_employee)
                   .includes(:manager)
                   .order(deadline: :asc)

    @objectives = @objectives.where(status: params[:status]) if params[:status].present?
  end

  def show
    @objective = Objective.find(params[:id])
    authorize @objective
  end
end
