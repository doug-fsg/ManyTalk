# frozen_string_literal: true

class Seeders::WorkflowScheduleSeeder
  PIPELINE_KEY = 'pipeline_seed_agendamentos'
  PIPELINE_NAME = 'Pipeline (seed agendamentos)'
  STAGES = ['Novo', 'Proposta', 'Fechado'].freeze
  TARGET_STAGE = 'Proposta'
  WORKFLOW_NAME = 'Disparo semanal — seed'
  SCHEDULE_NAME = 'Quarta na etapa Proposta (seed)'

  def initialize(account:)
    @account = account
  end

  def perform!
    enable_workflows!
    pipeline = find_or_create_pipeline!
    workflow = find_or_create_workflow!
    seed_contacts_on_stage!(pipeline)
    schedule = find_or_create_schedule!(workflow, pipeline)

    {
      account_id: @account.id,
      pipeline_id: pipeline.id,
      workflow_id: workflow.id,
      schedule_id: schedule.id,
      audience_count: schedule.audience_count
    }
  end

  private

  def enable_workflows!
    @account.enable_features!('workflows') unless @account.feature_enabled?('workflows')
  end

  def find_or_create_pipeline!
    existing = @account.custom_attribute_definitions.kanban_attributes.find_by(attribute_key: PIPELINE_KEY)
    return existing if existing

    @account.custom_attribute_definitions.create!(
      attribute_display_name: PIPELINE_NAME,
      attribute_key: PIPELINE_KEY,
      attribute_display_type: :list,
      attribute_model: :contact_attribute,
      is_kanban: true,
      attribute_values: STAGES
    )
  end

  def find_or_create_workflow!
    existing = @account.workflows.find_by(name: WORKFLOW_NAME)
    return existing if existing

    @account.workflows.create!(
      name: WORKFLOW_NAME,
      description: 'Fluxo seed para disparo recorrente: envia uma mensagem. Troque por Chamar cliente se quiser usar a IA.',
      active: true,
      graph: workflow_graph
    )
  end

  def workflow_graph
    settings = Workflows::Constants::DEFAULT_SETTINGS.merge(
      'allow_reenrollment' => true,
      'reenrollment_min_interval_days' => 6,
      'reenrollment_on_cancel' => true,
      'cancel_on_agent_reply' => true,
      'pause_on_contact_reply' => true
    )

    {
      'nodes' => [
        {
          'id' => 'trigger_1',
          'type' => 'trigger',
          'data' => { 'event_name' => 'manual', 'conditions' => [] }
        },
        {
          'id' => 'action_1',
          'type' => 'action',
          'data' => {
            'label' => 'Mensagem semanal',
            'action_name' => 'send_message',
            'action_params' => ['Olá! Passando para acompanhar sua proposta. Posso ajudar com alguma dúvida?']
          }
        }
      ],
      'edges' => [
        { 'id' => 'e1', 'source' => 'trigger_1', 'target' => 'action_1' }
      ],
      'settings' => settings
    }
  end

  def seed_contacts_on_stage!(pipeline)
    [
      { name: 'Ana Seed', email: 'ana.seed@example.com', phone_number: '+5511999000001' },
      { name: 'Bruno Seed', email: 'bruno.seed@example.com', phone_number: '+5511999000002' }
    ].each do |attrs|
      contact = @account.contacts.find_or_initialize_by(email: attrs[:email])
      contact.assign_attributes(name: attrs[:name], phone_number: attrs[:phone_number])
      contact.save!

      ContactPipelinePosition.find_or_create_by!(contact: contact, pipeline: pipeline) do |position|
        position.stage_id = TARGET_STAGE
        position.entered_at = Time.current
        position.position = 0
      end
    end
  end

  def find_or_create_schedule!(workflow, pipeline)
    existing = @account.workflow_schedules.find_by(name: SCHEDULE_NAME)
    return existing if existing

    @account.workflow_schedules.create!(
      name: SCHEDULE_NAME,
      workflow: workflow,
      pipeline: pipeline,
      stage_id: TARGET_STAGE,
      weekday: 3,
      hour: 9,
      minute: 0,
      time_zone: 'America/Sao_Paulo',
      active: false
    )
  end
end
