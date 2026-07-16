namespace :chatwoot do
  namespace :kanban do
    desc 'Check legacy Kanban JSON still stored on contacts'
    task consistency_check: :environment do
      puts '🔍 Verificação de dados legados do Kanban'
      puts '=' * 60

      pipelines = CustomAttributeDefinition.kanban_attributes
                                           .where(attribute_model: 'contact_attribute')

      if pipelines.empty?
        puts '⚠️  Nenhum pipeline Kanban encontrado!'
        next
      end

      total_stale_json = 0
      total_missing_in_table = 0

      pipelines.each do |pipeline|
        puts "\n📊 Pipeline: #{pipeline.attribute_display_name} (#{pipeline.attribute_key})"
        puts '-' * 60

        contacts_with_json = Contact.where(account_id: pipeline.account_id).where(
          "custom_attributes->>? IS NOT NULL AND custom_attributes->>? != ''",
          pipeline.attribute_key, pipeline.attribute_key
        )

        table_count = ContactPipelinePosition.where(pipeline_id: pipeline.id).count
        json_count = contacts_with_json.count

        puts "Contatos em contact_pipeline_positions: #{table_count}"
        puts "Contatos com JSON legado em custom_attributes: #{json_count}"

        stale_json = 0
        missing_in_table = 0

        contacts_with_json.find_each do |contact|
          position = ContactPipelinePosition.find_by(contact_id: contact.id, pipeline_id: pipeline.id)

          if position
            stale_json += 1
          else
            missing_in_table += 1
            puts "  ⚠️  Contato #{contact.id} tem JSON mas não existe em contact_pipeline_positions"
          end
        end

        additional_json_count = Contact.where(account_id: pipeline.account_id).where(
          "additional_attributes->'kanban'->? IS NOT NULL",
          pipeline.id.to_s
        ).count

        if additional_json_count.positive?
          puts "Contatos com JSON legado em additional_attributes.kanban: #{additional_json_count}"
          stale_json += additional_json_count
        end

        puts "JSON legado com registro na tabela (fonte da verdade = tabela): #{stale_json}"
        puts "JSON legado sem registro na tabela: #{missing_in_table}"

        total_stale_json += stale_json
        total_missing_in_table += missing_in_table
      end

      puts "\n#{'=' * 60}"
      puts '📈 Resumo:'
      puts "  Registros JSON legados detectados: #{total_stale_json}"
      puts "  Contatos só no JSON (precisam migrar): #{total_missing_in_table}"

      if total_stale_json.positive? || total_missing_in_table.positive?
        puts "\n💡 Execute: rake chatwoot:kanban:cleanup_legacy_json"
        puts '   ou: rake chatwoot:kanban:migrate_data[sync]'
      else
        puts "\n✅ Nenhum dado legado encontrado. Kanban usa apenas contact_pipeline_positions."
      end
    end

    desc 'Remove legacy Kanban JSON from contacts already stored in contact_pipeline_positions'
    task cleanup_legacy_json: :environment do
      puts '🧹 Limpando JSON legado do Kanban'
      puts '=' * 60

      pipelines = CustomAttributeDefinition.kanban_attributes
                                           .where(attribute_model: 'contact_attribute')

      cleaned = 0
      imported = 0

      pipelines.find_each do |pipeline|
        puts "\n📊 Pipeline: #{pipeline.attribute_display_name}"

        Contact.where(account_id: pipeline.account_id).where(
          "custom_attributes->>? IS NOT NULL OR additional_attributes->'kanban'->? IS NOT NULL",
          pipeline.attribute_key,
          pipeline.id.to_s
        ).find_each do |contact|
          position = ContactPipelinePosition.find_by(contact_id: contact.id, pipeline_id: pipeline.id)

          if position
            cleaned += 1 if Contacts::KanbanLegacyCleanup.cleanup!(contact, pipeline)
          else
            imported += 1 if Contacts::KanbanLegacyCleanup.import_from_json!(contact, pipeline)
          end
        end
      end

      puts "\n✅ Limpeza concluída"
      puts "  JSON removido de contatos já migrados: #{cleaned}"
      puts "  Contatos importados do JSON para a tabela: #{imported}"
    end

    desc 'Migrate existing Kanban data from JSON to contact_pipeline_positions table'
    task :migrate_data, [:sync] => :environment do |_t, args|
      puts '🚀 Iniciando migração de dados do Kanban'
      puts '=' * 60

      pipelines = CustomAttributeDefinition.kanban_attributes
                                           .where(attribute_model: 'contact_attribute')

      if pipelines.empty?
        puts '⚠️  Nenhum pipeline Kanban encontrado!'
        next
      end

      puts "Pipelines encontrados: #{pipelines.count}"
      pipelines.each do |pipeline|
        puts "  - #{pipeline.attribute_display_name} (ID: #{pipeline.id})"
      end

      print "\n⚠️  Deseja continuar com a migração? (y/N): "
      response = $stdin.gets.chomp.downcase

      unless %w[y yes].include?(response)
        puts '❌ Migração cancelada pelo usuário.'
        next
      end

      if args[:sync] == 'sync' || ENV['SYNC'] == 'true'
        puts "\n📦 Executando migração de forma síncrona..."

        pipelines.each do |pipeline|
          puts "\n  Migrando pipeline: #{pipeline.attribute_display_name}..."
          Contacts::MigrateKanbanDataJob.new.perform(pipeline.id, 0)
          puts "  ✅ Pipeline #{pipeline.attribute_display_name} migrado!"
        end

        puts "\n✅ Migração concluída!"
        puts "   Use 'rake chatwoot:kanban:consistency_check' para verificar."
      else
        puts "\n📦 Enfileirando jobs de migração..."

        pipelines.each do |pipeline|
          Contacts::MigrateKanbanDataJob.perform_later(pipeline.id, 0)
          puts "  ✅ Job enfileirado para pipeline: #{pipeline.attribute_display_name}"
        end

        puts "\n✅ Migração iniciada!"
        puts "   Use 'rake chatwoot:kanban:consistency_check' para verificar o progresso."
        puts "\n💡 Para executar de forma síncrona: rake chatwoot:kanban:migrate_data[sync]"
      end
    end
  end
end
