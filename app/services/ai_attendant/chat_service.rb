# frozen_string_literal: true

class AiAttendant::ChatService
  TIMEZONE = 'America/Sao_Paulo'
  MAX_ITERATIONS = 5
  # 1 crédito abstrato por 1000 tokens (créditos = total_tokens / 1000).
  TOKENS_PER_CREDIT = 1000

  BASE_TOOLS = [
    {
      type: 'function',
      function: {
        name: 'current_datetime',
        description: 'Retorna a data e hora atuais em ISO 8601 no fuso America/Sao_Paulo.',
        parameters: {
          type: 'object',
          properties: {},
          additionalProperties: false
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'handoff_to_human',
        description: 'Encaminha a conversa para um atendente humano.',
        parameters: {
          type: 'object',
          properties: {
            summary: {
              type: 'string',
              description: 'Resumo do motivo do encaminhamento.'
            }
          },
          required: ['summary']
        }
      }
    }
  ].freeze

  COMPLETE_BEHAVIOR_STEP_TOOL = {
    type: 'function',
    function: {
      name: 'complete_behavior_step',
      description: 'Marca o passo atual do roteiro (modo estrito) como concluído e libera o próximo passo.',
      parameters: {
        type: 'object',
        properties: {
          evidence: {
            type: 'string',
            description: 'Resumo do que o cliente confirmou ou do que foi cumprido neste passo.'
          }
        },
        required: ['evidence']
      }
    }
  }.freeze

  pattr_initialize [:conversation!, :config!, :system!, :user!, :history!, { sandbox: false }]

  def perform
    @sandbox_step_index = 0
    return empty_result unless PlatformAi::QuotaGuard.allow?(account: account)

    messages = build_messages
    tokens = 0
    handed_off = false

    MAX_ITERATIONS.times do
      response = complete(messages)
      return empty_result(handoff: handed_off, tokens: tokens) if response.nil?

      tokens += response[:total_tokens].to_i
      tool_calls = Array(response[:tool_calls])

      if tool_calls.any?
        messages << assistant_tool_call_message(response, tool_calls)
        tool_calls.each do |tool_call|
          content, called_handoff = execute_tool(tool_call)
          handed_off ||= called_handoff
          messages << tool_result_message(tool_call, content)
          refresh_system_prompt!(messages) if behavior_step_tool?(tool_call)
        end
        next
      end

      text = response[:content].presence
      return empty_result(handoff: handed_off, tokens: tokens) if text.blank?

      credits = sandbox? ? 0 : credits_from(tokens)
      PlatformAi::QuotaGuard.charge!(account: account, credits: credits) unless sandbox?
      return result(text: text, handoff: handed_off, tokens: tokens, credits_charged: credits)
    end

    empty_result(handoff: handed_off, tokens: tokens)
  end

  private

  def account
    conversation.account
  end

  def build_messages
    [
      { role: 'system', content: system },
      *normalized_history,
      { role: 'user', content: user }
    ]
  end

  def normalized_history
    Array(history).map do |message|
      {
        role: message[:role] || message['role'],
        content: message[:content] || message['content']
      }
    end
  end

  def complete(messages)
    PlatformAi::ChatClient.complete(messages: messages, tools: tools_for_request)
  rescue PlatformAi::ChatClient::RequestError, StandardError
    nil
  end

  def assistant_tool_call_message(response, tool_calls)
    {
      role: 'assistant',
      content: response[:content],
      tool_calls: tool_calls
    }
  end

  def tool_result_message(tool_call, content)
    {
      role: 'tool',
      tool_call_id: tool_call_id(tool_call),
      content: content
    }
  end

  def execute_tool(tool_call)
    name = tool_name(tool_call)
    args = tool_arguments(tool_call)

    case name
    when 'current_datetime'
      [Time.current.in_time_zone(TIMEZONE).iso8601, false]
    when 'handoff_to_human'
      [handoff_tool_result(args['summary'].to_s), true]
    when 'complete_behavior_step'
      [complete_behavior_step_result(args['evidence'].to_s), false]
    else
      [{ error: "unknown tool #{name}" }.to_json, false]
    end
  end

  def tool_name(tool_call)
    function = tool_call['function'] || tool_call[:function] || {}
    function['name'] || function[:name]
  end

  def tool_call_id(tool_call)
    tool_call['id'] || tool_call[:id]
  end

  def tool_arguments(tool_call)
    function = tool_call['function'] || tool_call[:function] || {}
    raw = function['arguments'] || function[:arguments] || '{}'
    parsed = raw.is_a?(String) ? JSON.parse(raw) : raw
    parsed.stringify_keys
  rescue JSON::ParserError
    {}
  end

  def sandbox?
    sandbox == true
  end

  def tools_for_request
    tools = BASE_TOOLS.dup
    tools << COMPLETE_BEHAVIOR_STEP_TOOL if behavior_script.strict?
    tools
  end

  def behavior_script
    @behavior_script ||= AiAttendant::BehaviorScript.from_config(config)
  end

  def current_behavior_step_index
    if sandbox?
      @sandbox_step_index
    elsif conversation.contact.blank?
      0
    else
      AiAttendant::BehaviorProgress.load(
        contact: conversation.contact,
        conversation: conversation
      ).step_index
    end
  end

  def behavior_step_tool?(tool_call)
    tool_name(tool_call) == 'complete_behavior_step'
  end

  def refresh_system_prompt!(messages)
    return unless behavior_script.strict?

    messages[0][:content] = AiAttendant::PromptBuilder.build_system(
      config: config,
      conversation: sandbox? ? nil : conversation,
      behavior_step_index: current_behavior_step_index
    )
  end

  def complete_behavior_step_result(evidence)
    if sandbox?
      result = AiAttendant::BehaviorProgress.sandbox_advance(
        script: behavior_script,
        step_index: @sandbox_step_index,
        evidence: evidence
      )
      @sandbox_step_index += 1 if result[:ok]
      return result.to_json
    end

    AiAttendant::BehaviorProgress.advance!(
      contact: conversation.contact,
      conversation: conversation,
      script: behavior_script,
      evidence: evidence
    ).to_json
  end

  def handoff_tool_result(summary)
    return { assigned: false, assignee_id: nil }.to_json if sandbox?

    AiAttendant::HandoffService.new(
      conversation: conversation,
      summary: summary,
      config: config
    ).perform.to_json
  end

  def credits_from(tokens)
    tokens.to_d / TOKENS_PER_CREDIT
  end

  def empty_result(handoff: false, tokens: 0)
    result(text: nil, handoff: handoff, tokens: tokens, credits_charged: 0)
  end

  def result(text:, handoff:, tokens:, credits_charged:)
    { text: text, handoff: handoff, tokens: tokens, credits_charged: credits_charged }
  end
end
