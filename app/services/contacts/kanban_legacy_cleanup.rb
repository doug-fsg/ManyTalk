# frozen_string_literal: true

module Contacts
  # Remove dados legados do Kanban em contacts.custom_attributes e
  # contacts.additional_attributes.kanban após a migração para contact_pipeline_positions.
  class KanbanLegacyCleanup
    def self.import_from_json!(contact, pipeline)
      new(contact, pipeline).import_from_json!
    end

    def self.cleanup!(contact, pipeline)
      new(contact, pipeline).cleanup!
    end

    def initialize(contact, pipeline)
      @contact = contact
      @pipeline = pipeline
    end

    def import_from_json!
      return nil unless @pipeline&.is_kanban?

      existing = ContactPipelinePosition.find_by(
        contact_id: @contact.id,
        pipeline_id: @pipeline.id
      )

      if existing
        cleanup!
        return existing
      end

      stage_id = stage_from_json
      if stage_id.blank?
        cleanup!
        return nil
      end

      position = ContactPipelinePosition.new(
        contact_id: @contact.id,
        pipeline_id: @pipeline.id,
        stage_id: stage_id,
        deal_value: deal_value_from_json,
        entered_at: entered_at_from_json || Time.current,
        metadata: metadata_from_json
      )

      return nil unless position.save

      position
    rescue StandardError => e
      Rails.logger.error(
        "Erro ao importar dados legados do Kanban para contato #{@contact.id}, pipeline #{@pipeline.id}: #{e.message}"
      )
      nil
    end

    def cleanup!
      return false unless @pipeline&.is_kanban?

      updates = {}

      if @contact.custom_attributes.is_a?(Hash) && @contact.custom_attributes.key?(@pipeline.attribute_key)
        custom_attributes = @contact.custom_attributes.except(@pipeline.attribute_key)
        updates[:custom_attributes] = custom_attributes
      end

      additional_attributes = cleanup_additional_attributes(@contact.additional_attributes)
      if additional_attributes != @contact.additional_attributes
        updates[:additional_attributes] = additional_attributes
      end

      return false if updates.blank?

      @contact.update_columns(updates)
      true
    end

    private

    def stage_from_json
      @contact.custom_attributes&.dig(@pipeline.attribute_key).presence
    end

    def deal_value_from_json
      kanban_data = pipeline_kanban_json
      kanban_data&.dig('deal', 'value')
    end

    def entered_at_from_json
      entered_at_str = pipeline_kanban_json&.dig('stage_tracking', 'current', 'entered_at')
      return nil if entered_at_str.blank?

      Time.zone.parse(entered_at_str)
    rescue ArgumentError, TypeError
      nil
    end

    def metadata_from_json
      kanban_data = pipeline_kanban_json || {}
      {
        'win_lost' => kanban_data['win_lost'],
        'other_data' => kanban_data.except('deal', 'stage_tracking', 'win_lost')
      }.compact
    end

    def pipeline_kanban_json
      @contact.additional_attributes&.dig('kanban', @pipeline.id.to_s)
    end

    def cleanup_additional_attributes(additional_attributes)
      additional_attributes = additional_attributes.presence || {}
      kanban_data = additional_attributes['kanban']
      return additional_attributes unless kanban_data.is_a?(Hash)
      return additional_attributes unless kanban_data.key?(@pipeline.id.to_s)

      updated_kanban = kanban_data.except(@pipeline.id.to_s)
      updated_additional = additional_attributes.dup

      if updated_kanban.empty?
        updated_additional.delete('kanban')
      else
        updated_additional['kanban'] = updated_kanban
      end

      updated_additional
    end
  end
end
