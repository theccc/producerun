class Projects::ContributionsController < ApplicationController
  inherit_resources
  actions :index, :show, :new, :update, :review, :create
  skip_before_filter :verify_authenticity_token, only: [:moip]
  has_scope :available_to_count, type: :boolean
  has_scope :with_state
  has_scope :page, default: 1
  after_filter :verify_authorized, except: [:index]
  belongs_to :project
  before_filter :detect_old_browsers, only: [:new, :create]

  helper_method :avaiable_payment_engines

  def edit
    authorize resource
    if resource.reward.try(:sold_out?)
      flash[:alert] = t('.reward_sold_out')
      return redirect_to new_project_contribution_path(@project)
    end
  end

  def update
    authorize resource
    resource.update_attributes(permitted_params[:contribution])
    resource.update_user_billing_info
    render json: {message: 'updated'}
  end

  def index
    render collection
  end

  def show
    authorize resource
    @title = t('projects.contributions.show.title')
  end

  def new
    @contribution = Contribution.new(project: parent, user: current_user)
    @contribution.value = 10
    authorize @contribution

    @title = t('projects.contributions.new.title', name: @project.name)
    load_rewards

    # Select
    if params[:reward_id] && (@selected_reward = @project.rewards.find params[:reward_id]) && !@selected_reward.sold_out?
      @contribution.reward = @selected_reward
      @contribution.value = "%0.0f" % @selected_reward.minimum_value
    end
  end

  def create
    @title = t('projects.contributions.create.title')
    @contribution = parent.contributions.new.localized
    @contribution.user = current_user
    @contribution.value = permitted_params[:contribution][:value]
    @contribution.reward_id = (params[:contribution][:reward_id].to_i == 0 ? nil : params[:contribution][:reward_id])
    authorize @contribution
    @contribution.update_current_billing_info
    create! do |success,failure|
      failure.html do
        flash[:alert] = resource.errors.full_messages.to_sentence
        load_rewards
        render :new
      end
      success.html do
        flash[:notice] = nil
        session[:thank_you_contribution_id] = @contribution.id
        return redirect_to edit_project_contribution_path(project_id: @project.id, id: @contribution.id)
      end
    end
    @thank_you_id = @project.id
  end

  protected
  def load_rewards
    # empty_reward = Reward.new(minimum_value: 0, description: t('projects.contributions.new.no_reward'))
    @rewards = @project.rewards.remaining.order(:minimum_value)
  end

  def permitted_params
    params.permit(policy(resource).permitted_attributes)
  end

  def avaiable_payment_engines
    @engines ||= if parent.using_pagarme?
      [PaymentEngines.find_engine('braintree')].compact
    else
      PaymentEngines.engines.inject([]) do |total, item|
        total << item unless item.name == 'braintree'
        total
      end
    end
  end

  def collection
    @contributions ||= apply_scopes(end_of_association_chain).available_to_display.order("confirmed_at DESC").per(10)
  end
end
