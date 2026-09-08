# frozen_string_literal: true

module Workflows
  module Constants
    ALLOWED_TRIGGER_EVENTS = %w[
      manual
      contact_kanban_stage_created
      contact_kanban_stage_changed
      contact_kanban_stage_idle
      conversation_created
      conversation_updated
      conversation_opened
      conversation_resolved
      message_created
      form_submitted
    ].freeze

    ALLOWED_ACTION_NAMES = %w[
      send_message
      add_label
      remove_label
      send_email_to_team
      assign_team
      assign_agent
      send_webhook_event
      mute_conversation
      send_attachment
      change_status
      resolve_conversation
      snooze_conversation
      change_priority
      send_email_transcript
      send_email_to_contact
      change_kanban_stage
      add_private_note
      send_whatsapp_external
    ].freeze

    WAIT_RESPONDERS = %w[contact agent any].freeze

    NODE_TYPES = %w[trigger wait wait_for_reply condition action ai_outreach ai_conversation_analysis ai_wait_for_intent].freeze

    AI_ANALYSIS_TYPES = %w[
      executive_summary
      service_quality
      sales_opportunities
      customer_sentiment
      next_action
    ].freeze

    AI_ANALYSIS_OUTPUT_DESTINATIONS = %w[private_note whatsapp_external].freeze

    MAX_AI_ANALYSIS_MESSAGES = 100

    AI_OUTREACH_OBJECTIVES = %w[
      reengagement
      follow_up
      reminder
      appointment
      payment
    ].freeze

    AI_OUTREACH_TONES = %w[
      friendly
      professional
      sales
      support
    ].freeze

    AI_LANGUAGES = %w[
      client
      pt_BR
      pt_PT
      es
      en
    ].freeze

    MAX_AI_OUTREACH_PROMPT_LENGTH = 500

    AI_OUTREACH_OBJECTIVE_PROMPTS = {
      'reengagement' => 'Retome o contato com o cliente de forma amigável.',
      'follow_up' => 'Pergunte se o cliente ainda precisa de ajuda.',
      'reminder' => 'Lembre o cliente sobre o assunto em aberto.',
      'appointment' => 'Confirme o horário combinado com o cliente.',
      'payment' => 'Retome com o cliente sobre o pagamento pendente de forma educada.'
    }.freeze

    AI_OUTREACH_TONE_PREFIXES = {
      'friendly' => 'Tom amigável e próximo.',
      'professional' => 'Tom profissional e objetivo.',
      'sales' => 'Tom persuasivo, focado em conversão.',
      'support' => 'Tom empático, focado em resolver o problema.'
    }.freeze

    BRANCH_NODE_TYPES = %w[condition wait_for_reply ai_wait_for_intent].freeze

    CONDITION_SOURCE_HANDLES = %w[true false].freeze
    REPLY_WATCH_SOURCE_HANDLES = %w[replied timeout].freeze
    INTENT_WATCH_SOURCE_HANDLES = %w[intent_detected timeout].freeze

    MAX_INTENT_DESCRIPTION_LENGTH = 500

    # Horizontal catalog — searchable in the editor; not tied to a single niche.
    AI_INTENT_CATALOG = [
      {
        key: 'schedule_visit',
        label: 'Agendar visita',
        description: 'Cliente quer marcar visita, horário ou reunião',
        examples: ['quero agendar', 'tem horário disponível', 'pode marcar uma visita']
      },
      {
        key: 'quote_request',
        label: 'Pedido de orçamento',
        description: 'Cliente pede proposta, cotação ou preço',
        examples: ['quero um orçamento', 'quanto custa', 'manda a proposta']
      },
      {
        key: 'technical_support',
        label: 'Suporte técnico',
        description: 'Cliente relata problema técnico ou pede ajuda',
        examples: ['não funciona', 'preciso de suporte', 'está com erro']
      },
      {
        key: 'cancellation',
        label: 'Cancelamento',
        description: 'Cliente quer cancelar pedido, serviço ou contrato',
        examples: ['quero cancelar', 'cancela meu pedido', 'não quero mais']
      },
      {
        key: 'payment_confirmed',
        label: 'Pagamento confirmado',
        description: 'Cliente informa que já pagou ou enviou comprovante',
        examples: ['já paguei', 'fiz o pix', 'enviei o comprovante']
      },
      {
        key: 'product_info',
        label: 'Informações do produto',
        description: 'Cliente quer detalhes sobre produto ou serviço',
        examples: ['como funciona', 'quais as opções', 'tem em estoque']
      },
      {
        key: 'order_status',
        label: 'Status do pedido',
        description: 'Cliente pergunta andamento de pedido ou entrega',
        examples: ['cadê meu pedido', 'já saiu para entrega', 'qual o status']
      },
      {
        key: 'human_agent',
        label: 'Falar com atendente',
        description: 'Cliente pede atendimento humano',
        examples: ['quero falar com alguém', 'atendente', 'pessoa real']
      },
      {
        key: 'complaint',
        label: 'Reclamação',
        description: 'Cliente expressa insatisfação ou reclama',
        examples: ['quero reclamar', 'péssimo atendimento', 'não resolveu']
      },
      {
        key: 'purchase_intent',
        label: 'Intenção de compra',
        description: 'Cliente demonstra interesse em comprar',
        examples: ['quero comprar', 'vou fechar', 'pode reservar']
      },
      {
        key: 'delivery_question',
        label: 'Dúvida sobre entrega',
        description: 'Cliente pergunta prazo, frete ou endereço de entrega',
        examples: ['quando chega', 'frete grátis', 'entrega hoje']
      },
      {
        key: 'reschedule',
        label: 'Remarcar',
        description: 'Cliente quer alterar data ou horário já combinado',
        examples: ['preciso remarcar', 'muda o horário', 'outro dia']
      },
      {
        key: 'confirmation',
        label: 'Confirmação',
        description: 'Cliente confirma presença, pedido ou acordo',
        examples: ['confirmo', 'pode confirmar', 'estarei lá']
      },
      {
        key: 'catalog_request',
        label: 'Ver catálogo',
        description: 'Cliente quer ver opções, lista ou portfólio',
        examples: ['manda o catálogo', 'quais opções', 'ver produtos']
      },
      {
        key: 'contract_question',
        label: 'Dúvida contratual',
        description: 'Cliente pergunta sobre contrato, plano ou termos',
        examples: ['como funciona o plano', 'qual o contrato', 'renovação']
      },
      {
        key: 'documentation_request',
        label: 'Solicitar documentação',
        description: 'Cliente pede nota fiscal, boleto ou documento',
        examples: ['manda a nota', 'preciso do boleto', 'documentação']
      },
      # Legacy keys kept for graphs saved before catalog expansion
      {
        key: 'menu_request',
        label: 'Ver catálogo',
        description: 'Cliente quer ver opções, menu ou portfólio',
        examples: ['quero o cardápio', 'manda o menu', 'ver opções']
      }
    ].freeze

    WAIT_UNITS = %w[minutes hours days].freeze

    WAIT_LIMITS = {
      'minutes' => { min: 1, max: 43_200 },
      'hours' => { min: 1, max: 720 },
      'days' => { min: 1, max: 90 }
    }.freeze

    MAX_GRAPH_BYTES = 512.kilobytes
    MAX_SEND_MESSAGE_ACTIONS = 15
    MAX_ACTIONS_PER_NODE = 20
    MAX_WAIT_NODES = 10
    MAX_WORKFLOWS_PER_EVENT = 100
    # After this many synchronous node advances, enqueue StepJob to avoid long-running jobs
    MAX_SYNC_ADVANCE_DEPTH = 5

    DEFAULT_SETTINGS = {
      'cancel_on_contact_reply' => false,
      'pause_on_contact_reply' => true,
      'cancel_on_conversation_resolved' => true,
      'cancel_on_agent_reply' => false,
      'cancel_on_labels' => [],
      'allow_manual_start_only' => false,
      'enroll_latest_conversation_only' => true,
      'enrollment_scope' => 'contact',
      'respect_business_hours' => true,
      'allow_reenrollment' => false,
      'reenrollment_min_interval_days' => 30,
      'max_enrollments_per_contact' => 0,
      'reenrollment_on_cancel' => true
    }.freeze

    ENROLLMENT_SCOPES = %w[contact conversation].freeze
  end
end
