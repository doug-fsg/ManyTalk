# frozen_string_literal: true

class Api::V1::Accounts::WorkflowsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_workflow, only: [:show, :update, :destroy, :clone, :toggle_active, :dry_run]

  def index
    @workflows = Current.account.workflows.order(updated_at: :desc)
    @metrics = Workflows::ListMetricsService.new(
      account: Current.account,
      user: current_user,
      workflow_ids: @workflows.map(&:id)
    ).build
  end

  def show; end

  def templates
    @templates = Workflows::TemplateFactory.available_templates
  end

  def from_template
    @workflow = Workflows::TemplateFactory.clone_to_account(
      params[:template_key],
      account: Current.account,
      user: current_user
    )
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def validate
    graph = normalize_graph_param
    result = Workflows::GraphValidationService.new(graph: graph, account: Current.account).perform
    render json: result
  end

  def create
    result = Workflows::CreateService.new(
      account: Current.account,
      user: current_user,
      params: workflow_params
    ).perform

    if result[:workflow].present?
      @workflow = result[:workflow]
    else
      render json: { error: result[:errors] }, status: :unprocessable_entity
    end
  end

  def update
    result = Workflows::UpdateService.new(
      workflow: @workflow,
      user: current_user,
      params: workflow_params
    ).perform

    if result[:errors].blank?
      @workflow = result[:workflow]
    else
      render json: { error: result[:errors] }, status: :unprocessable_entity
    end
  end

  def destroy
    Workflows::DestroyService.new(workflow: @workflow).perform
    head :ok
  end

  def clone
    source = Current.account.workflows.find(params[:id])
    @workflow = source.dup
    @workflow.name = "#{source.name} #{I18n.t('workflows.clone_suffix')}"
    @workflow.active = false
    @workflow.created_by = current_user
    @workflow.updated_by = current_user
    @workflow.save!
  end

  def toggle_active
    activating = !@workflow.active
    if activating
      result = Workflows::GraphValidationService.new(graph: @workflow.graph, account: Current.account).perform
      unless result[:valid]
        errors = Workflows::GraphValidationService.error_messages(result[:errors])
        return render json: { error: errors }, status: :unprocessable_entity
      end
    end
    @workflow.update!(active: activating, updated_by: current_user)
    if activating
      Workflows::ActivationService.new.resume_inactive!(@workflow)
    else
      Workflows::ActivationService.new.pause_in_progress!(@workflow)
    end
    @workflow
  end

  def dry_run
    conversation = nil
    if params[:conversation_id].present?
      conversation = Current.account.conversations.find_by(id: params[:conversation_id])
      return render json: { error: 'conversation_not_found' }, status: :not_found if conversation.blank?
    end

    result = Workflows::DryRunService.new(
      workflow: @workflow,
      conversation: conversation,
      decisions: dry_run_decisions_param,
      auto_skip_waits: ActiveModel::Type::Boolean.new.cast(params[:auto_skip_waits])
    ).perform

    render json: result
  end

  def test_external_whatsapp
    result = Workflows::ExternalWhatsappNotifier.new(
      account: Current.account,
      inbox_id: params[:inbox_id],
      phone_number: params[:phone_number],
      message: params[:message].presence || 'Teste — Fluxo de Atendimento'
    ).send!

    if result[:success]
      render json: { success: true, message_id: result[:message_id], delivery: result[:delivery] }
    else
      render json: { error: result[:error], detail: result[:detail] }, status: :unprocessable_entity
    end
  end

  private

  def normalize_graph_param
    graph = Workflows::GraphParamsParser.to_hash(params[:graph]) if params[:graph].present?
    graph ||= { 'nodes' => [], 'edges' => [], 'settings' => Workflows::Constants::DEFAULT_SETTINGS }
    graph['settings'] = Workflows::Constants::DEFAULT_SETTINGS.merge(graph['settings'] || {})
    graph
  end

  def workflow_params
    base = params.permit(:name, :description, :active).to_h
    base['graph'] = Workflows::GraphParamsParser.to_hash(params[:graph]) if params[:graph].present?
    base.with_indifferent_access
  end

  def fetch_workflow
    @workflow = Current.account.workflows.find(params[:id])
  end

  def dry_run_decisions_param
    Array(params[:decisions]).map do |entry|
      if entry.respond_to?(:permit)
        entry.permit(:node_id, :branch).to_h
      else
        entry.to_h.slice('node_id', 'branch')
      end
    end
  end
end
