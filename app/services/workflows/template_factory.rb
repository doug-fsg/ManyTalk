# frozen_string_literal: true

require 'set'

module Workflows
  class TemplateFactory
    CATEGORIES = %w[atendimento vendas operacional marketing].freeze

    # Defaults operacionais para templates comerciais / follow-up
    FOLLOW_UP_SETTINGS = Constants::DEFAULT_SETTINGS.merge(
      'cancel_on_agent_reply' => true,
      'pause_on_contact_reply' => true
    ).freeze

    REACTIVATION_SETTINGS = Constants::DEFAULT_SETTINGS.merge(
      'allow_reenrollment' => true,
      'reenrollment_min_interval_days' => 30,
      'max_enrollments_per_contact' => 5,
      'reenrollment_on_cancel' => true,
      'cancel_on_agent_reply' => true,
      'pause_on_contact_reply' => true,
      'allow_manual_start_only' => true
    ).freeze

    TEMPLATES = {
      'follow_up_basic' => {
        name: 'Follow-up básico (3 etapas)',
        description: 'Fluxo de Atendimento com 3 mensagens de follow-up quando o cliente não responde.',
        category: 'atendimento',
        trigger_event: 'manual',
        graph: {
          'nodes' => [
            { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'manual' } },
            { 'id' => 'action_1', 'type' => 'action', 'data' => { 'label' => 'Enviar mensagem 1', 'action_name' => 'send_message', 'action_params' => ['Olá! Tudo bem? Gostaria de saber se tem alguma dúvida.'] } },
            { 'id' => 'wait_reply_1', 'type' => 'wait_for_reply', 'data' => { 'label' => 'Aguardar resposta — 6h', 'duration' => 6, 'unit' => 'hours' } },
            { 'id' => 'action_2', 'type' => 'action', 'data' => { 'label' => 'Enviar mensagem 2', 'action_name' => 'send_message', 'action_params' => ['Oi! Passando para verificar se posso ajudar em algo.'] } },
            { 'id' => 'wait_reply_2', 'type' => 'wait_for_reply', 'data' => { 'label' => 'Aguardar resposta — 24h', 'duration' => 24, 'unit' => 'hours' } },
            { 'id' => 'action_3', 'type' => 'action', 'data' => { 'label' => 'Enviar mensagem 3', 'action_name' => 'send_message', 'action_params' => ['Olá! Ainda estou à disposição caso precise.'] } }
          ],
          'edges' => [
            { 'source' => 'trigger_1', 'target' => 'action_1' },
            { 'source' => 'action_1', 'target' => 'wait_reply_1' },
            { 'source' => 'wait_reply_1', 'target' => 'action_2', 'sourceHandle' => 'timeout' },
            { 'source' => 'action_2', 'target' => 'wait_reply_2' },
            { 'source' => 'wait_reply_2', 'target' => 'action_3', 'sourceHandle' => 'timeout' }
          ],
          'settings' => FOLLOW_UP_SETTINGS
        }
      },
      'crm_stage_changed' => {
        name: 'Boas-vindas ao mudar estágio no CRM',
        description: 'Envia mensagem quando o contato avança de estágio no pipeline do CRM.',
        category: 'vendas',
        trigger_event: 'contact_kanban_stage_changed',
        graph: {
          'nodes' => [
            {
              'id' => 'trigger_1',
              'type' => 'trigger',
              'data' => {
                'event_name' => 'contact_kanban_stage_changed',
                'conditions' => []
              }
            },
            {
              'id' => 'wait_1',
              'type' => 'wait',
              'data' => { 'label' => 'Espera 15 min', 'duration' => 15, 'unit' => 'minutes' }
            },
            {
              'id' => 'action_1',
              'type' => 'action',
              'data' => {
                'label' => 'Mensagem de boas-vindas ao estágio',
                'action_name' => 'send_message',
                'action_params' => ['Olá! Vi que você avançou no nosso processo. Posso ajudar com os próximos passos?']
              }
            }
          ],
          'edges' => [
            { 'source' => 'trigger_1', 'target' => 'wait_1' },
            { 'source' => 'wait_1', 'target' => 'action_1' }
          ],
          'settings' => FOLLOW_UP_SETTINGS
        }
      },
      'welcome_conversation' => {
        name: 'Boas-vindas na conversa criada',
        description: 'Mensagem automática de boas-vindas quando uma nova conversa é aberta.',
        category: 'atendimento',
        trigger_event: 'conversation_created',
        graph: {
          'nodes' => [
            {
              'id' => 'trigger_1',
              'type' => 'trigger',
              'data' => {
                'event_name' => 'conversation_created',
                'conditions' => []
              }
            },
            {
              'id' => 'action_1',
              'type' => 'action',
              'data' => {
                'label' => 'Mensagem de boas-vindas',
                'action_name' => 'send_message',
                'action_params' => ['Olá! Obrigado por entrar em contato. Em breve um atendente irá te ajudar.']
              }
            },
            {
              'id' => 'wait_1',
              'type' => 'wait',
              'data' => { 'label' => 'Espera 1h', 'duration' => 1, 'unit' => 'hours' }
            },
            {
              'id' => 'action_2',
              'type' => 'action',
              'data' => {
                'label' => 'Follow-up após espera',
                'action_name' => 'send_message',
                'action_params' => ['Oi! Ainda estamos à disposição. Posso ajudar em algo?']
              }
            }
          ],
          'edges' => [
            { 'source' => 'trigger_1', 'target' => 'action_1' },
            { 'source' => 'action_1', 'target' => 'wait_1' },
            { 'source' => 'wait_1', 'target' => 'action_2' }
          ],
          'settings' => FOLLOW_UP_SETTINGS.merge(
            'cancel_on_agent_reply' => false,
            'pause_on_contact_reply' => true
          )
        }
      },
      'reactivation_30d' => {
        name: 'Reativação (30 dias)',
        description: 'Régua manual para reengajar ex-clientes ou contatos inativos. Permite reentrada após 30 dias.',
        category: 'vendas',
        trigger_event: 'manual',
        graph: {
          'nodes' => [
            { 'id' => 'trigger_1', 'type' => 'trigger', 'data' => { 'event_name' => 'manual' } },
            {
              'id' => 'action_1',
              'type' => 'action',
              'data' => {
                'label' => 'Mensagem de reativação',
                'action_name' => 'send_message',
                'action_params' => ['Olá! Faz um tempo que não conversamos. Posso ajudar com algo novo?']
              }
            },
            {
              'id' => 'wait_reply_1',
              'type' => 'wait_for_reply',
              'data' => { 'label' => 'Aguardar resposta — 48h', 'duration' => 48, 'unit' => 'hours' }
            },
            {
              'id' => 'action_2',
              'type' => 'action',
              'data' => {
                'label' => 'Segundo toque',
                'action_name' => 'send_message',
                'action_params' => ['Oi! Passando para saber se ainda posso ajudar. Fico à disposição.']
              }
            }
          ],
          'edges' => [
            { 'source' => 'trigger_1', 'target' => 'action_1' },
            { 'source' => 'action_1', 'target' => 'wait_reply_1' },
            { 'source' => 'wait_reply_1', 'target' => 'action_2', 'sourceHandle' => 'timeout' }
          ],
          'settings' => REACTIVATION_SETTINGS
        }
      }
    }.freeze

    def self.available_templates
      TEMPLATES.map do |key, tpl|
        {
          key: key,
          name: tpl[:name],
          description: tpl[:description],
          category: tpl[:category],
          trigger_event: tpl[:trigger_event],
          step_count: step_count_for(tpl[:graph])
        }
      end
    end

    def self.available_categories
      CATEGORIES
    end

    def self.clone_to_account(template_key, account:, user:)
      template = TEMPLATES[template_key]
      raise ArgumentError, "Unknown template: #{template_key}" if template.blank?

      graph = template[:graph].deep_dup
      layout_graph!(graph)
      validation = GraphValidationService.new(graph: graph, account: account).perform
      raise ArgumentError, validation[:errors].map { |e| e[:message] }.join(', ') unless validation[:valid]

      account.workflows.create!(
        name: template[:name],
        description: template[:description],
        graph: graph,
        active: false,
        created_by: user,
        updated_by: user
      )
    end

    def self.step_count_for(graph)
      (graph['nodes'] || []).count { |node| node['type'] != 'trigger' }
    end

    def self.layout_graph!(graph)
      nodes = graph['nodes'] || []
      edges = graph['edges'] || []
      return if nodes.empty?

      return if nodes.all? { |node| node['x'].present? || node.dig('position', 'x').present? }

      trigger = nodes.find { |node| node['type'] == 'trigger' }
      return if trigger.blank?

      adjacency = edges.each_with_object({}) do |edge, memo|
        memo[edge['source']] ||= []
        memo[edge['source']] << edge['target']
      end

      layout_meta = {}
      visited = Set.new

      visit = lambda do |node_id, depth, row|
        return if visited.include?(node_id)

        visited.add(node_id)
        layout_meta[node_id] = { depth: depth, row: row }
        (adjacency[node_id] || []).each_with_index do |child_id, index|
          visit.call(child_id, depth + 1, row + index)
        end
      end

      visit.call(trigger['id'], 0, 0)

      extra_depth = (layout_meta.values.map { |meta| meta[:depth] }.max || 0) + 1
      nodes.each do |node|
        next if visited.include?(node['id'])

        layout_meta[node['id']] = { depth: extra_depth, row: 0 }
        extra_depth += 1
      end

      h_step = 184
      v_step = 120
      start_x = 120
      start_y = 120

      nodes.each do |node|
        meta = layout_meta[node['id']] || { depth: 0, row: 0 }
        x = start_x + (meta[:depth] * h_step)
        y = start_y + (meta[:row] * v_step)
        node['x'] = x
        node['y'] = y
        node['position'] = { 'x' => x, 'y' => y }
      end
    end

    private_class_method :step_count_for, :layout_graph!
  end
end
