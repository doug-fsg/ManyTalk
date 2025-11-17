namespace :chatwoot do
  namespace :kanban do
    desc 'Test dual-write functionality for Kanban'
    task test_dual_write: :environment do
      puts "🧪 Testando funcionalidade de dual-write do Kanban"
      puts "=" * 60

      # 1. Buscar um pipeline kanban de teste
      pipeline = CustomAttributeDefinition.kanban_attributes
        .where(attribute_model: 'contact_attribute')
        .first

      if pipeline.blank?
        puts "❌ Nenhum pipeline Kanban encontrado!"
        puts "   Crie um pipeline kanban primeiro para testar."
        exit 1
      end

      puts "✅ Pipeline encontrado: #{pipeline.attribute_display_name} (ID: #{pipeline.id})"
      puts "   Attribute Key: #{pipeline.attribute_key}"

      # 2. Buscar ou criar um contato de teste
      account = pipeline.account
      contact = account.contacts.first

      if contact.blank?
        puts "❌ Nenhum contato encontrado na conta!"
        exit 1
      end

      puts "✅ Contato de teste: #{contact.name || contact.email} (ID: #{contact.id})"

      # 3. Obter stages disponíveis
      stages = pipeline.attribute_values
      if stages.blank?
        puts "❌ Nenhum stage configurado no pipeline!"
        exit 1
      end

      test_stage = stages.first
      puts "✅ Stage de teste: #{test_stage}"

      # 4. Testar atualização do contato
      puts "\n📝 Atualizando contato com stage '#{test_stage}'..."
      
      old_custom_attrs = contact.custom_attributes.dup
      contact.custom_attributes = contact.custom_attributes.merge({
        pipeline.attribute_key => test_stage
      })

      # Adicionar dados adicionais do kanban
      contact.additional_attributes ||= {}
      contact.additional_attributes['kanban'] ||= {}
      contact.additional_attributes['kanban'][pipeline.id.to_s] = {
        'stage_tracking' => {
          'current' => {
            'stage_id' => test_stage,
            'entered_at' => Time.current.iso8601
          }
        },
        'deal' => {
          'value' => 1000.50
        }
      }

      contact.save!
      puts "✅ Contato atualizado!"

      # 5. Aguardar processamento assíncrono
      puts "\n⏳ Aguardando 2 segundos para processamento assíncrono..."
      sleep 2

      # 6. Verificar se foi sincronizado para a tabela
      puts "\n🔍 Verificando sincronização na tabela contact_pipeline_positions..."
      
      position = ContactPipelinePosition.find_by(
        contact_id: contact.id,
        pipeline_id: pipeline.id
      )

      if position.blank?
        puts "❌ FALHA: Registro não encontrado na tabela contact_pipeline_positions!"
        puts "   O dual-write pode não estar funcionando."
        puts "\n💡 Dica: Verifique se o Sidekiq está rodando:"
        puts "   bundle exec sidekiq -q default -q mailers -q async_database_migration"
        exit 1
      end

      puts "✅ Registro encontrado na tabela!"
      puts "\n📊 Dados sincronizados:"
      puts "   - Contact ID: #{position.contact_id}"
      puts "   - Pipeline ID: #{position.pipeline_id}"
      puts "   - Stage ID: #{position.stage_id}"
      puts "   - Deal Value: #{position.deal_value}"
      puts "   - Entered At: #{position.entered_at}"
      puts "   - Metadata: #{position.metadata}"

      # 7. Validar consistência
      puts "\n🔍 Validando consistência dos dados..."
      
      errors = []
      
      if position.stage_id != test_stage
        errors << "Stage ID não corresponde: esperado '#{test_stage}', obtido '#{position.stage_id}'"
      end

      if position.deal_value.to_f != 1000.50
        errors << "Deal Value não corresponde: esperado 1000.50, obtido #{position.deal_value}"
      end

      if errors.any?
        puts "❌ FALHA: Inconsistências encontradas:"
        errors.each { |error| puts "   - #{error}" }
        exit 1
      end

      puts "✅ Dados consistentes!"

      # 8. Testar atualização de stage
      puts "\n📝 Testando atualização de stage..."
      
      if stages.length > 1
        new_stage = stages[1]
        puts "   Mudando para stage: #{new_stage}"
        
        contact.custom_attributes = contact.custom_attributes.merge({
          pipeline.attribute_key => new_stage
        })
        contact.save!

        # Aguardar processamento assíncrono (aumentar tempo para garantir)
        puts "   Aguardando processamento assíncrono..."
        sleep 5

        # Recarregar position da tabela
        position.reload
        
        if position.stage_id == new_stage
          puts "✅ Stage atualizado corretamente na tabela!"
        else
          puts "❌ FALHA: Stage não foi atualizado. Esperado '#{new_stage}', obtido '#{position.stage_id}'"
          puts "   💡 O job assíncrono pode não ter sido processado ainda."
          puts "   💡 Certifique-se de que o Sidekiq está rodando:"
          puts "      bundle exec sidekiq -q default -q mailers -q async_database_migration"
          puts "   💡 Ou aguarde mais tempo e execute novamente."
          exit 1
        end
      else
        puts "⚠️  Apenas 1 stage disponível, pulando teste de atualização."
      end

      # 8.5. Testar atualização de deal_value sem mudar stage
      puts "\n📝 Testando atualização de deal_value..."
      
      new_deal_value = 2500.75
      contact.additional_attributes['kanban'][pipeline.id.to_s]['deal'] = { 'value' => new_deal_value }
      contact.save!

      sleep 2

      position.reload
      
      if position.deal_value.to_f == new_deal_value
        puts "✅ Deal value atualizado corretamente: #{position.deal_value}"
      else
        puts "❌ FALHA: Deal value não foi atualizado. Esperado #{new_deal_value}, obtido #{position.deal_value}"
        exit 1
      end

      # 8.6. Testar atualização de metadata
      puts "\n📝 Testando atualização de metadata (win/lost)..."
      
      contact.additional_attributes['kanban'][pipeline.id.to_s]['win_lost'] = {
        'status' => 'won',
        'reason' => 'Cliente fechou contrato',
        'date' => Time.current.iso8601
      }
      contact.save!

      sleep 2

      position.reload
      
      if position.metadata.present? && position.metadata['win_lost'].present?
        puts "✅ Metadata atualizado corretamente: #{position.metadata['win_lost']}"
      else
        puts "❌ FALHA: Metadata não foi atualizado. Obtido: #{position.metadata}"
        exit 1
      end

      # 9. Testar remoção
      puts "\n📝 Testando remoção do pipeline..."
      
      contact.custom_attributes = contact.custom_attributes.except(pipeline.attribute_key)
      contact.save!

      sleep 2

      position_after_removal = ContactPipelinePosition.find_by(
        contact_id: contact.id,
        pipeline_id: pipeline.id
      )

      if position_after_removal.present?
        puts "⚠️  Registro ainda existe na tabela após remoção."
        puts "   Isso pode ser esperado dependendo da implementação."
      else
        puts "✅ Registro removido da tabela!"
      end

      puts "\n" + "=" * 60
      puts "✅ TESTE CONCLUÍDO COM SUCESSO!"
      puts "\n📈 Resumo:"
      puts "   - Dual-write está funcionando corretamente"
      puts "   - Dados são sincronizados automaticamente"
      puts "   - Consistência entre JSON e tabela verificada"
      puts "\n💡 Próximos passos:"
      puts "   1. Execute a migração de dados existentes:"
      puts "      rake chatwoot:kanban:migrate_data"
      puts "   2. Verifique a consistência:"
      puts "      rake chatwoot:kanban:consistency_check"
    end
  end
end

