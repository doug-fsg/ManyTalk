# frozen_string_literal: true

# Compatibilidade retroativa para jobs/rakes legados.
# Preferir Contacts::KanbanLegacyCleanup diretamente.
class Contacts::KanbanSyncService
  def initialize(contact, pipeline_id)
    @contact = contact
    @pipeline = CustomAttributeDefinition.find_by(id: pipeline_id)
  end

  def sync_to_table
    sync_to_table_without_flag_check
  end

  def sync_to_table_without_flag_check
    Contacts::KanbanLegacyCleanup.import_from_json!(@contact, @pipeline)
  end
end
