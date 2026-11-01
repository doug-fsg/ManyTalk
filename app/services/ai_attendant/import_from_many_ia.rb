# frozen_string_literal: true

module AiAttendant
  class ImportFromManyIa
    class Error < StandardError; end

    SCHEDULE_MODE_MAP = {
      'Atender 24h por dia' => 'always',
      'Dentro do horário de atendimento' => 'within_inbox_hours',
      'Fora do horário de atendimento' => 'outside_inbox_hours'
    }.freeze

    def self.call(account:, payload:)
      new(account: account, payload: payload).call
    end

    def initialize(account:, payload:)
      @account = account
      @payload = payload.to_h.stringify_keys
    end

    def call
      many_ia_config_id
      owned_inbox
      config = account.ai_attendant_configs.find_or_initialize_by(many_ia_config_id: many_ia_config_id)
      config.assign_attributes(mapped_attributes)
      config.save!
      config.ai_attendant_config_inboxes.find_or_create_by!(inbox_id: owned_inbox.id)
      EnsureSenderBot.for(config: config)
      config
    end

    private

    attr_reader :account, :payload

    def many_ia_config_id
      @many_ia_config_id ||= begin
        id = payload['id'].presence
        raise Error, 'id is required' if id.blank?

        id.to_s
      end
    end

    def owned_inbox
      @owned_inbox ||= begin
        inbox = account.inboxes.find_by(id: payload['inboxId'])
        raise Error, 'inboxId must belong to the account' if inbox.blank?

        inbox
      end
    end

    def mapped_attributes
      {
        active: boolean_value(payload['isActive']),
        detect_language: boolean_value(payload['detectarIdioma']),
        digital_agent_name: payload['nomeAtendenteDigital'],
        agent_role: payload['quemEhAtendente'],
        agent_duties: payload['oQueAtendenteFaz'],
        agent_objective: payload['objetivoAtendente'],
        behavior_steps: map_string_list(payload['comoAtendenteDeve'], keys: %w[conteudo]),
        company_context: payload['informacoesEmpresa'],
        topics_to_avoid: map_string_list(payload['temasEvitar'], keys: %w[conteudo tema]),
        handoff_conditions: payload['condicoesAtendimento'],
        schedule_mode: map_schedule_mode(payload['horarioAtendimento'])
      }
    end

    def map_schedule_mode(value)
      SCHEDULE_MODE_MAP.fetch(value.to_s, 'always')
    end

    def map_string_list(value, keys:)
      normalize_list(value).filter_map { |item| extract_text(item, keys: keys) }
    end

    def normalize_list(value)
      case value
      when Array
        value
      when String
        parse_json_array(value) || [value]
      when Hash
        [value]
      else
        []
      end
    end

    def extract_text(item, keys:)
      case item
      when Hash
        hash = item.stringify_keys
        keys.filter_map { |key| hash[key].presence }.first&.to_s
      when String
        item.presence
      else
        item.to_s.presence
      end
    end

    def parse_json_array(value)
      parsed = JSON.parse(value)
      parsed.is_a?(Array) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def boolean_value(value)
      ActiveModel::Type::Boolean.new.cast(value) || false
    end
  end
end
