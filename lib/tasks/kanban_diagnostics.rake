namespace :chatwoot do
  namespace :kanban do
    desc 'Diagnose Kanban performance and data structure'
    task diagnostics: :environment do
      puts "🔍 Diagnóstico de Performance do Kanban"
      puts "=" * 60
      
      # 1. Estatísticas de pipelines Kanban
      puts "\n📊 1. Estatísticas de Pipelines Kanban"
      puts "-" * 60
      
      kanban_attributes = CustomAttributeDefinition.kanban_attributes
        .where(attribute_model: 'contact_attribute')
      
      total_pipelines = kanban_attributes.count
      puts "Total de pipelines Kanban: #{total_pipelines}"
      
      if total_pipelines == 0
        puts "⚠️  Nenhum pipeline Kanban encontrado!"
        return
      end
      
      kanban_attributes.each do |attr|
        puts "\n  Pipeline: #{attr.attribute_display_name} (#{attr.attribute_key})"
        puts "    ID: #{attr.id}"
        puts "    Etapas: #{attr.attribute_values&.length || 0}"
        
        # Contar contatos por etapa
        if attr.attribute_values.present?
          attr.attribute_values.each do |stage|
            count = Contact.where(
              "custom_attributes->>? IS NOT NULL AND custom_attributes->>? != ''",
              attr.attribute_key, attr.attribute_key
            ).where(
              "custom_attributes->>? = ?",
              attr.attribute_key, stage
            ).count
            
            puts "      - #{stage}: #{count} contatos"
          end
        end
        
        # Contar total de contatos com este atributo
        total_with_attr = Contact.where(
          "custom_attributes->>? IS NOT NULL AND custom_attributes->>? != ''",
          attr.attribute_key, attr.attribute_key
        ).count
        
        puts "    Total de contatos: #{total_with_attr}"
      end
      
      # 2. Análise de performance de queries
      puts "\n⏱️  2. Análise de Performance de Queries"
      puts "-" * 60
      
      kanban_attributes.each do |attr|
        puts "\n  Testando queries para: #{attr.attribute_display_name}"
        
        # Query is_present
        start_time = Time.current
        result = Contact.where(
          "custom_attributes->>? IS NOT NULL AND custom_attributes->>? != ''",
          attr.attribute_key, attr.attribute_key
        ).limit(1).count
        duration = ((Time.current - start_time) * 1000).round(2)
        
        puts "    Query 'is_present' (primeira execução): #{duration}ms"
        
        # Query usando operador ? (precisa escapar a chave para evitar SQL injection)
        escaped_key = ActiveRecord::Base.connection.quote_string(attr.attribute_key)
        start_time = Time.current
        result = Contact.where("custom_attributes ? '#{escaped_key}'").limit(1).count
        duration = ((Time.current - start_time) * 1000).round(2)
        
        puts "    Query usando operador '?' (primeira execução): #{duration}ms"
        
        # Query por etapa específica
        if attr.attribute_values.present?
          stage = attr.attribute_values.first
          start_time = Time.current
          result = Contact.where("custom_attributes->>? = ?", attr.attribute_key, stage)
            .limit(1).count
          duration = ((Time.current - start_time) * 1000).round(2)
          
          puts "    Query por etapa '#{stage}': #{duration}ms"
        end
      end
      
      # 3. Análise de índices existentes
      puts "\n🗂️  3. Análise de Índices Existentes"
      puts "-" * 60
      
      connection = ActiveRecord::Base.connection
      indexes = connection.indexes('contacts')
      
      kanban_indexes = indexes.select { |idx| 
        idx.name.include?('custom_attributes') || 
        idx.name.include?('additional_attributes') ||
        idx.name.include?('kanban')
      }
      
      if kanban_indexes.any?
        puts "Índices relacionados ao Kanban encontrados:"
        kanban_indexes.each do |idx|
          # idx.columns pode ser array ou string (para índices funcionais)
          columns_display = idx.columns.is_a?(Array) ? idx.columns.join(', ') : idx.columns.to_s
          puts "  - #{idx.name}: #{columns_display}"
        end
      else
        puts "⚠️  Nenhum índice específico para Kanban encontrado"
        puts "   Recomendação: Criar índices específicos para melhorar performance"
      end
      
      # 4. Análise de additional_attributes.kanban
      puts "\n📦 4. Análise de Estrutura additional_attributes.kanban"
      puts "-" * 60
      
      contacts_with_kanban_data = Contact.where(
        "additional_attributes->'kanban' IS NOT NULL"
      ).count
      
      puts "Contatos com dados em additional_attributes.kanban: #{contacts_with_kanban_data}"
      
      if contacts_with_kanban_data > 0
        # Amostra de estrutura
        sample = Contact.where(
          "additional_attributes->'kanban' IS NOT NULL"
        ).limit(5)
        
        puts "\n  Estrutura de exemplo (primeiros 5 contatos):"
        sample.each do |contact|
          kanban_data = contact.additional_attributes&.dig('kanban')
          if kanban_data.present?
            puts "    Contato ID #{contact.id}:"
            kanban_data.each do |pipeline_id, data|
              puts "      Pipeline #{pipeline_id}:"
              puts "        Estágio atual: #{data.dig('stage_tracking', 'current', 'stage_id')}"
              puts "        Valor do negócio: #{data.dig('deal', 'value')}"
              puts "        Status Win/Lost: #{data.dig('win_lost', 'status')}"
            end
          end
        end
      end
      
      # 5. Recomendações
      puts "\n💡 5. Recomendações"
      puts "-" * 60
      
      total_contacts = Contact.count
      contacts_with_kanban = Contact.where(
        "EXISTS (SELECT 1 FROM jsonb_object_keys(custom_attributes) AS key WHERE key IN (SELECT attribute_key FROM custom_attribute_definitions WHERE is_kanban = true AND attribute_model = 1))"
      ).count
      
      puts "Total de contatos no sistema: #{total_contacts}"
      puts "Contatos usando Kanban: #{contacts_with_kanban}"
      
      if total_contacts > 1000 && contacts_with_kanban > 500
        puts "\n⚠️  ALERTA: Volume alto de contatos detectado!"
        puts "   Recomendações:"
        puts "   1. Implementar paginação no frontend"
        puts "   2. Criar índices específicos para queries do Kanban"
        puts "   3. Considerar estrutura de dados dedicada para Kanban"
      end
      
      if kanban_indexes.empty?
        puts "\n⚠️  ALERTA: Índices específicos não encontrados!"
        puts "   Recomendação: Executar migração para criar índices otimizados"
      end
      
      puts "\n✅ Diagnóstico concluído!"
      puts "=" * 60
    end
    
    desc 'Show slow queries related to Kanban (requires pg_stat_statements)'
    task slow_queries: :environment do
      puts "🐌 Queries Lentas Relacionadas ao Kanban"
      puts "=" * 60
      
      connection = ActiveRecord::Base.connection
      
      # Verificar se pg_stat_statements está disponível
      begin
        result = connection.execute("
          SELECT 
            query,
            calls,
            total_exec_time,
            mean_exec_time,
            max_exec_time
          FROM pg_stat_statements
          WHERE query LIKE '%custom_attributes%' 
             OR query LIKE '%additional_attributes%'
             OR query LIKE '%kanban%'
          ORDER BY mean_exec_time DESC
          LIMIT 10
        ")
        
        if result.any?
          puts "\nTop 10 queries mais lentas relacionadas ao Kanban:\n"
          result.each_with_index do |row, index|
            puts "#{index + 1}. Tempo médio: #{row['mean_exec_time'].to_f.round(2)}ms"
            puts "   Execuções: #{row['calls']}"
            puts "   Query: #{row['query'][0..200]}..."
            puts ""
          end
        else
          puts "⚠️  Nenhuma query encontrada ou pg_stat_statements não está habilitado"
          puts "   Para habilitar: ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';"
        end
      rescue => e
        puts "⚠️  Erro ao consultar pg_stat_statements: #{e.message}"
        puts "   Esta funcionalidade requer a extensão pg_stat_statements habilitada"
      end
    end
  end
end

