# frozen_string_literal: true

class OneOnOnesController < ApplicationController
  before_action :authenticate_employee!

  def index
    @one_on_ones = policy_scope(OneOnOne)
                    .includes(:manager)
                    .order(scheduled_at: :desc)
  end

  def show
    @one_on_one = OneOnOne.find(params[:id])
    authorize @one_on_one
  end
end
