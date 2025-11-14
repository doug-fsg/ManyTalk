namespace :chatwoot do
  namespace :kanban do
    desc 'Check consistency between JSON structure and contact_pipeline_positions table'
    task consistency_check: :environment do
      puts "🔍 Verificação de Consistência do Kanban"
      puts "=" * 60

      pipelines = CustomAttributeDefinition.kanban_attributes
        .where(attribute_model: 'contact_attribute')

      if pipelines.empty?
        puts "⚠️  Nenhum pipeline Kanban encontrado!"
        return
      end

      total_errors = 0
      total_checked = 0

      pipelines.each do |pipeline|
        puts "\n📊 Verificando pipeline: #{pipeline.attribute_display_name} (#{pipeline.attribute_key})"
        puts "-" * 60

        # Contatos com dados no JSON
        contacts_in_json = Contact.where(
          "custom_attributes->>? IS NOT NULL AND custom_attributes->>? != ''",
          pipeline.attribute_key, pipeline.attribute_key
        )

        # Contatos com dados na tabela
        contacts_in_table = Contact.joins(
          "INNER JOIN contact_pipeline_positions ON contact_pipeline_positions.contact_id = contacts.id"
        ).where("contact_pipeline_positions.pipeline_id = ?", pipeline.id)

        json_count = contacts_in_json.count
        table_count = contacts_in_table.count

        puts "Contatos no JSON: #{json_count}"
        puts "Contatos na tabela: #{table_count}"

        # Verificar inconsistências
        errors = []

        # 1. Contatos no JSON mas não na tabela
        contacts_in_json.find_each do |contact|
          total_checked += 1
          position = ContactPipelinePosition.find_by(
            contact_id: contact.id,
            pipeline_id: pipeline.id
          )

          unless position
            errors << {
              type: 'missing_in_table',
              contact_id: contact.id,
              stage_in_json: contact.custom_attributes[pipeline.attribute_key]
            }
            next
          end

          # 2. Verificar se stage_id bate
          json_stage = contact.custom_attributes[pipeline.attribute_key]
          if position.stage_id != json_stage
            errors << {
              type: 'stage_mismatch',
              contact_id: contact.id,
              stage_in_json: json_stage,
              stage_in_table: position.stage_id
            }
          end

          # 3. Verificar deal_value
          json_deal_value = contact.additional_attributes&.dig('kanban', pipeline.id.to_s, 'deal', 'value')
          if json_deal_value.present? && position.deal_value != json_deal_value.to_f
            errors << {
              type: 'deal_value_mismatch',
              contact_id: contact.id,
              value_in_json: json_deal_value,
              value_in_table: position.deal_value
            }
          end
        end

        # 4. Contatos na tabela mas não no JSON (orphans)
        contacts_in_table.find_each do |contact|
          json_stage = contact.custom_attributes&.dig(pipeline.attribute_key)
          unless json_stage.present?
            errors << {
              type: 'orphan_in_table',
              contact_id: contact.id,
              stage_in_table: ContactPipelinePosition.find_by(
                contact_id: contact.id,
                pipeline_id: pipeline.id
              )&.stage_id
            }
          end
        end

        if errors.any?
          puts "\n❌ Encontradas #{errors.size} inconsistências:"
          errors.first(10).each do |error|
            puts "  - #{error[:type]}: Contato ID #{error[:contact_id]}"
            if error[:stage_in_json] && error[:stage_in_table]
              puts "    JSON: #{error[:stage_in_json]} | Tabela: #{error[:stage_in_table]}"
            end
          end
          puts "  ... e mais #{errors.size - 10} inconsistências" if errors.size > 10
          total_errors += errors.size
        else
          puts "\n✅ Nenhuma inconsistência encontrada!"
        end
      end

      puts "\n" + "=" * 60
      puts "📈 Resumo:"
      puts "  Contatos verificados: #{total_checked}"
      puts "  Inconsistências encontradas: #{total_errors}"

      if total_errors > 0
        puts "\n⚠️  Recomendação: Execute a migração de dados para corrigir inconsistências"
        puts "   rake chatwoot:kanban:migrate_data"
      else
        puts "\n✅ Dados consistentes entre JSON e tabela!"
      end
    end

    desc 'Migrate existing Kanban data from JSON to contact_pipeline_positions table'
    task :migrate_data, [:sync] => :environment do |_t, args|
      puts "🚀 Iniciando migração de dados do Kanban"
      puts "=" * 60

      pipelines = CustomAttributeDefinition.kanban_attributes
        .where(attribute_model: 'contact_attribute')

      if pipelines.empty?
        puts "⚠️  Nenhum pipeline Kanban encontrado!"
        return
      end

      puts "Pipelines encontrados: #{pipelines.count}"
      pipelines.each do |pipeline|
        puts "  - #{pipeline.attribute_display_name} (ID: #{pipeline.id})"
      end

      print "\n⚠️  Deseja continuar com a migração? (y/N): "
      response = STDIN.gets.chomp.downcase

      unless response == 'y' || response == 'yes'
        puts "❌ Migração cancelada pelo usuário."
        return
      end

      # Se --sync foi passado, executar de forma síncrona (útil para testes)
      if args[:sync] == 'sync' || ENV['SYNC'] == 'true'
        puts "\n📦 Executando migração de forma síncrona..."
        
        pipelines.each do |pipeline|
          puts "\n  Migrando pipeline: #{pipeline.attribute_display_name}..."
          Contacts::MigrateKanbanDataJob.new.perform(pipeline.id, 0)
          puts "  ✅ Pipeline #{pipeline.attribute_display_name} migrado!"
        end

        puts "\n✅ Migração concluída!"
        puts "   Use 'rake chatwoot:kanban:consistency_check' para verificar a consistência."
      else
        puts "\n📦 Enfileirando jobs de migração..."
        
        pipelines.each do |pipeline|
          Contacts::MigrateKanbanDataJob.perform_later(pipeline.id, 0)
          puts "  ✅ Job enfileirado para pipeline: #{pipeline.attribute_display_name}"
        end

        puts "\n✅ Migração iniciada!"
        puts "   Os jobs serão processados em background."
        puts "   Use 'rake chatwoot:kanban:consistency_check' para verificar o progresso."
        puts "\n💡 Dica: Para executar de forma síncrona (sem Sidekiq), use:"
        puts "   rake chatwoot:kanban:migrate_data[sync]"
      end
    end
  end
end

