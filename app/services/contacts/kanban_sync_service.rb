# Serviço para sincronização dual-write entre estrutura JSON atual e tabela contact_pipeline_positions
# Permite migração gradual sem quebrar funcionalidades existentes
class Contacts::KanbanSyncService
  def initialize(contact, pipeline_id)
    @contact = contact
    @pipeline_id = pipeline_id
    @pipeline = CustomAttributeDefinition.find_by(id: pipeline_id)
  end

  # Sincroniza dados do JSON para a tabela (dual-write)
  # Sempre habilitado - sem feature flag
  def sync_to_table
    sync_to_table_without_flag_check
  end

  # Versão pública que não verifica feature flag (usada durante migração)
  # Permite migração mesmo quando feature flag está desabilitada
  def sync_to_table_without_flag_check
    return unless @pipeline&.is_kanban?

    stage_id = get_stage_from_json
    return unless stage_id.present?

    deal_value = get_deal_value_from_json
    entered_at = get_entered_at_from_json
    metadata = get_metadata_from_json

    position = ContactPipelinePosition.find_or_initialize_by(
      contact_id: @contact.id,
      pipeline_id: @pipeline_id
    )

    position.assign_attributes(
      stage_id: stage_id,
      deal_value: deal_value,
      entered_at: entered_at || Time.current,
      metadata: metadata
    )

    position.save!
    position
  rescue => e
    Rails.logger.error("Erro ao sincronizar kanban para tabela: #{e.message}")
    # Não falhar silenciosamente - logar mas continuar funcionamento normal
    nil
  end

  # Sincroniza dados da tabela para o JSON (usado durante migração reversa)
  def sync_to_json
    position = ContactPipelinePosition.find_by(
      contact_id: @contact.id,
      pipeline_id: @pipeline_id
    )

    return unless position

    # Atualizar custom_attributes
    custom_attrs = @contact.custom_attributes || {}
    custom_attrs[@pipeline.attribute_key] = position.stage_id

    # Atualizar additional_attributes.kanban
    additional_attrs = @contact.additional_attributes || {}
    kanban_data = additional_attrs['kanban'] || {}
    pipeline_data = kanban_data[@pipeline_id.to_s] || {}

    pipeline_data['stage_tracking'] = {
      'current' => {
        'stage_id' => position.stage_id,
        'entered_at' => position.entered_at&.iso8601
      }
    }

    pipeline_data['deal'] = { 'value' => position.deal_value } if position.deal_value.present?
    pipeline_data['metadata'] = position.metadata if position.metadata.present?

    kanban_data[@pipeline_id.to_s] = pipeline_data
    additional_attrs['kanban'] = kanban_data

    @contact.update_columns(
      custom_attributes: custom_attrs,
      additional_attributes: additional_attrs
    )
  rescue => e
    Rails.logger.error("Erro ao sincronizar kanban para JSON: #{e.message}")
    nil
  end

  # Remove entrada da tabela quando contato é removido do pipeline
  def remove_from_table
    ContactPipelinePosition.where(
      contact_id: @contact.id,
      pipeline_id: @pipeline_id
    ).destroy_all
  rescue => e
    Rails.logger.error("Erro ao remover kanban da tabela: #{e.message}")
    nil
  end

  private

  def get_stage_from_json
    @contact.custom_attributes&.dig(@pipeline&.attribute_key)
  end

  def get_deal_value_from_json
    kanban_data = @contact.additional_attributes&.dig('kanban', @pipeline_id.to_s)
    kanban_data&.dig('deal', 'value')
  end

  def get_entered_at_from_json
    kanban_data = @contact.additional_attributes&.dig('kanban', @pipeline_id.to_s)
    entered_at_str = kanban_data&.dig('stage_tracking', 'current', 'entered_at')
    return nil unless entered_at_str

    Time.parse(entered_at_str) rescue nil
  end

  def get_metadata_from_json
    kanban_data = @contact.additional_attributes&.dig('kanban', @pipeline_id.to_s)
    {
      'win_lost' => kanban_data&.dig('win_lost'),
      'other_data' => kanban_data&.except('deal', 'stage_tracking', 'win_lost')
    }.compact
  end
end

