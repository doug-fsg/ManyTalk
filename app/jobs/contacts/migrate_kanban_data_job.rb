# Job para migrar dados existentes do Kanban da estrutura JSON para a tabela contact_pipeline_positions
# Executa em batches pequenos para não sobrecarregar o banco de dados
class Contacts::MigrateKanbanDataJob < ApplicationJob
  queue_as :async_database_migration

  BATCH_SIZE = 100

  def perform(pipeline_id = nil, batch_start = 0)
    # Se pipeline_id fornecido, migrar apenas esse pipeline
    # Caso contrário, migrar todos os pipelines Kanban
    pipelines = if pipeline_id
                  [CustomAttributeDefinition.find_by(id: pipeline_id, is_kanban: true)].compact
                else
                  CustomAttributeDefinition.kanban_attributes
                    .where(attribute_model: 'contact_attribute')
                end

    return if pipelines.empty?

    pipelines.each do |pipeline|
      migrate_pipeline(pipeline, batch_start)
    end
  end

  private

  def migrate_pipeline(pipeline, batch_start)
    Rails.logger.info("Iniciando migração de dados Kanban para pipeline: #{pipeline.attribute_display_name} (ID: #{pipeline.id})")

    # Buscar contatos que têm este atributo definido
    contacts = Contact.where(
      "custom_attributes->>? IS NOT NULL AND custom_attributes->>? != ''",
      pipeline.attribute_key, pipeline.attribute_key
    ).offset(batch_start).limit(BATCH_SIZE)

    migrated_count = 0
    error_count = 0

      contacts.find_each do |contact|
        begin
          sync_service = Contacts::KanbanSyncService.new(contact, pipeline.id)
          
          # Usar método que não verifica feature flag (permite migração mesmo com flag desabilitada)
          result = sync_service.sync_to_table_without_flag_check
          
          if result
            migrated_count += 1
          end
        rescue => e
          error_count += 1
          Rails.logger.error("Erro ao migrar contato #{contact.id} para pipeline #{pipeline.id}: #{e.message}")
        end
      end

    Rails.logger.info("Migração concluída para pipeline #{pipeline.id}: #{migrated_count} migrados, #{error_count} erros")

    # Se ainda há mais contatos, agendar próximo batch
    if contacts.count == BATCH_SIZE
      Contacts::MigrateKanbanDataJob.perform_later(pipeline.id, batch_start + BATCH_SIZE)
    end
  end
end

