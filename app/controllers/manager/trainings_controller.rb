module Manager
  class TrainingsController < ApplicationController
    before_action :authenticate_employee!
    before_action :set_training, only: [:show, :edit, :update, :destroy, :archive, :unarchive]

    def index
      @trainings = policy_scope(Training)
                     .includes(:organization)
                     .order(:title)

      if params[:training_type].present? && Training.training_types.key?(params[:training_type])
        @trainings = @trainings.by_type(params[:training_type])
      end

      if params[:archived] == 'true'
        @trainings = @trainings.archived
      else
        @trainings = @trainings.active
      end
    end

    def show
      @assignments = policy_scope(TrainingAssignment)
                       .where(training: @training)
                       .includes(:employee)
                       .order(assigned_at: :desc)
    end

    def new
      @training = Training.new(organization: current_organization)
      authorize @training
    end

    def create
      @training = Training.new(training_params.merge(organization: current_organization))
      authorize @training

      if @training.save
        redirect_to manager_training_path(@training), notice: 'Training created'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @training.update(training_params)
        redirect_to manager_training_path(@training), notice: 'Training updated'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @training.destroy
      redirect_to manager_trainings_path, notice: 'Training deleted'
    end

    def archive
      authorize @training, :archive?
      @training.archive!
      redirect_to manager_trainings_path, notice: 'Training archived'
    end

    def unarchive
      authorize @training, :archive?
      @training.unarchive!
      redirect_to manager_trainings_path, notice: 'Training restored'
    end

    private

    def set_training
      @training = Training.find(params[:id])
      authorize @training
    end

    def training_params
      params.require(:training).permit(
        :title, :description, :training_type, :duration_estimate,
        :provider, :external_url
      )
    end

    def current_organization
      current_employee.organization
    end
  end
end
