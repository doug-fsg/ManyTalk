# frozen_string_literal: true

module Workflows
  # Human-readable labels for workflow nodes shown in conversation UI (régua).
  # Prefer custom data.label; otherwise fall back to Portuguese names matching the editor.
  module NodeLabel
    module_function

    NODE_TYPE_LABELS = {
      'trigger' => 'Gatilho',
      'wait' => 'Espera',
      'wait_for_reply' => 'Aguardar resposta',
      'condition' => 'Se (IF)',
      'action' => 'Ação',
      'ai_outreach' => 'Chamar cliente',
      'ai_conversation_analysis' => 'Avaliar Conversa',
      'ai_wait_for_intent' => 'Aguardar intenção'
    }.freeze

    ACTION_NAME_LABELS = {
      'assign_agent' => 'Atribuir a um Atendente',
      'assign_team' => 'Atribuir a uma Equipe',
      'add_label' => 'Adicionar uma etiqueta',
      'remove_label' => 'Remover uma etiqueta',
      'send_email_to_team' => 'Enviar um email para a equipe',
      'send_email_transcript' => 'Enviar transcrição por email',
      'send_email_to_contact' => 'Enviar e-mail ao contato',
      'mute_conversation' => 'Silenciar conversa',
      'snooze_conversation' => 'Sonecar conversa',
      'resolve_conversation' => 'Resolver conversa',
      'send_webhook_event' => 'Enviar webhook',
      'send_attachment' => 'Enviar anexo',
      'send_message' => 'Enviar uma mensagem',
      'add_private_note' => 'Adicionar nota privada',
      'change_priority' => 'Alterar prioridade',
      'change_status' => 'Alterar status',
      'change_kanban_stage' => 'Alterar estágio do CRM',
      'send_whatsapp_external' => 'Enviar para WhatsApp externo',
      'remove_assigned_team' => 'Remover equipe atribuída'
    }.freeze

    TRIGGER_EVENT_LABELS = {
      'manual' => 'Início manual (pela conversa)',
      'contact_kanban_stage_created' => 'Estágio criado no pipeline',
      'contact_kanban_stage_changed' => 'Estágio do CRM alterado',
      'contact_kanban_stage_idle' => 'Parado no estágio do CRM (sem atividade)',
      'conversation_created' => 'Conversa criada',
      'conversation_updated' => 'Conversa atualizada',
      'conversation_opened' => 'Conversa aberta',
      'conversation_resolved' => 'Conversa resolvida',
      'message_created' => 'Mensagem criada',
      'form_submitted' => 'Formulário enviado'
    }.freeze

    WAIT_UNIT_LABELS = {
      'minutes' => 'minuto(s)',
      'hours' => 'hora(s)',
      'days' => 'dia(s)'
    }.freeze

    def for_node(node)
      return nil if node.blank?

      data = (node['data'] || {}).with_indifferent_access
      custom = data[:label].to_s.strip
      return custom if custom.present?

      case node['type']
      when 'action'
        action_label(data)
      when 'trigger'
        TRIGGER_EVENT_LABELS[data[:event_name].to_s] || NODE_TYPE_LABELS['trigger']
      when 'wait', 'wait_for_reply'
        wait_label(node['type'], data)
      else
        NODE_TYPE_LABELS[node['type']] || node['type']
      end
    end

    def action_label(data)
      items = Workflows::ActionNodeData.items(data)
      first_name = items.first&.dig('action_name').presence || data[:action_name].to_s
      label = ACTION_NAME_LABELS[first_name] || first_name.presence || NODE_TYPE_LABELS['action']
      return label if items.length <= 1

      "#{label} +#{items.length - 1}"
    end

    def wait_label(type, data)
      base = NODE_TYPE_LABELS[type] || type
      duration = data[:duration]
      unit = WAIT_UNIT_LABELS[data[:unit].to_s] || data[:unit]
      return base if duration.blank? || unit.blank?

      "#{base} · #{duration} #{unit}"
    end

    # Short explanations of what each action in an action-node does (for timeline info).
    def action_details(node)
      return [] if node.blank? || node['type'] != 'action'

      data = (node['data'] || {}).with_indifferent_access
      Workflows::ActionNodeData.items(data).filter_map { |item| describe_action(item) }
    end

    def describe_action(item)
      name = item['action_name'].to_s
      params = Array(item['action_params'])
      title = ACTION_NAME_LABELS[name] || name.presence
      return nil if title.blank?

      detail = action_detail_for(name, params)
      detail.present? ? "#{title}: #{detail}" : title
    end

    def action_detail_for(name, params)
      case name
      when 'send_message', 'add_private_note'
        truncate_text(params[0])
      when 'add_label', 'remove_label'
        params.map(&:to_s).reject(&:blank?).join(', ').presence
      when 'assign_agent', 'assign_team', 'change_priority', 'change_status'
        params[0].to_s.presence
      when 'send_webhook_event'
        truncate_text(params[0])
      when 'send_whatsapp_external'
        [params[1], truncate_text(params[2])].compact.map(&:to_s).reject(&:blank?).join(' · ').presence
      when 'change_kanban_stage'
        params.compact.map(&:to_s).reject(&:blank?).join(' → ').presence
      when 'send_attachment'
        count = params.length
        count.positive? ? "#{count} arquivo(s)" : nil
      end
    end

    def truncate_text(value, length = 72)
      text = value.to_s.gsub(/\s+/, ' ').strip
      return nil if text.blank?

      text.length > length ? "#{text[0, length - 1]}…" : text
    end
  end
end
