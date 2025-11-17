# Listener para sincronizar automaticamente dados do Kanban para a tabela contact_pipeline_positions
# Este listener captura eventos de atualização de contatos e faz o dual-write
class KanbanSyncListener < BaseListener
  include Events::Types

  def contact_updated(event)
    contact_id = event.data[:contact].id
    changed_attributes = event.data[:changed_attributes]

    # Verificar se custom_attributes ou additional_attributes foram alterados
    has_custom_attrs_change = changed_attributes&.key?('custom_attributes')
    has_additional_attrs_change = changed_attributes&.key?('additional_attributes')

    return unless has_custom_attrs_change || has_additional_attrs_change

    # Recarregar o contato do banco para ter os dados atualizados
    contact = Contact.find_by(id: contact_id)
    return unless contact

    # Buscar todos os pipelines kanban da conta
    kanban_pipelines = contact.account.custom_attribute_definitions
      .where(attribute_model: 'contact_attribute', is_kanban: true)

    return if kanban_pipelines.empty?

    # Sincronizar cada pipeline que foi alterado
    kanban_pipelines.each do |pipeline|
      should_sync = false

      # Verificar mudanças em custom_attributes (stage)
      if has_custom_attrs_change
        old_custom_attrs = changed_attributes['custom_attributes']&.first || {}
        new_custom_attrs = changed_attributes['custom_attributes']&.last || {}

        old_stage = old_custom_attrs[pipeline.attribute_key]
        new_stage = new_custom_attrs[pipeline.attribute_key]

        should_sync = true if new_stage.present? || old_stage != new_stage
      end

      # Verificar mudanças em additional_attributes (deal_value, metadata, etc)
      if has_additional_attrs_change
        old_additional_attrs = changed_attributes['additional_attributes']&.first || {}
        new_additional_attrs = changed_attributes['additional_attributes']&.last || {}

        old_kanban_data = old_additional_attrs.dig('kanban', pipeline.id.to_s)
        new_kanban_data = new_additional_attrs.dig('kanban', pipeline.id.to_s)

        # Se houve mudança nos dados do kanban deste pipeline, sincronizar
        should_sync = true if old_kanban_data != new_kanban_data
      end

      # Sincronizar se houver mudanças
      sync_pipeline(contact, pipeline) if should_sync
    end
  rescue StandardError => e
    Rails.logger.error("Erro no KanbanSyncListener: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Não propagar erro para não quebrar outros listeners
  end

  private

  def sync_pipeline(contact, pipeline)
    sync_service = Contacts::KanbanSyncService.new(contact, pipeline.id)

    # Verificar se o contato tem um stage definido para este pipeline
    stage_value = contact.custom_attributes&.dig(pipeline.attribute_key)

    if stage_value.present?
      # Sincronizar para a tabela (inclui stage, deal_value, metadata, etc)
      result = sync_service.sync_to_table
      
      if result
        deal_value = contact.additional_attributes&.dig('kanban', pipeline.id.to_s, 'deal', 'value')
        Rails.logger.info("Kanban sincronizado: Contact #{contact.id}, Pipeline #{pipeline.id}, Stage: #{stage_value}, Deal: #{deal_value}")
      end
    else
      # Remover da tabela se o valor foi removido
      sync_service.remove_from_table
      Rails.logger.info("Kanban removido da tabela: Contact #{contact.id}, Pipeline #{pipeline.id}")
    end
  end
end

