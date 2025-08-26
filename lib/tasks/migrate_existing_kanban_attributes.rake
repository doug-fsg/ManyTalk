namespace :chatwoot do
  desc 'Migrate existing list-type contact attributes to Kanban format'
  task migrate_kanban_attributes: :environment do
    puts "🚀 Iniciando migração de atributos Kanban existentes..."
    
    # Contar atributos antes da migração
    list_attributes = CustomAttributeDefinition.where(
      attribute_display_type: 'list',
      attribute_model: 'contact_attribute'
    )
    
    puts "📊 Encontrados #{list_attributes.count} atributos do tipo lista para contatos"
    
    if list_attributes.count == 0
      puts "✅ Nenhum atributo para migrar. Tarefa concluída."
      return
    end
    
    # Mostrar preview dos atributos que serão migrados
    puts "\n📋 Atributos que serão marcados como Kanban:"
    list_attributes.each do |attr|
      puts "  - #{attr.attribute_display_name} (#{attr.attribute_key})"
    end
    
    # Confirmar antes de prosseguir
    print "\n⚠️  Deseja continuar com a migração? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "❌ Migração cancelada pelo usuário."
      return
    end
    
    begin
      # Executar migração
      updated_count = list_attributes.update_all(is_kanban: true)
      
      # Verificar resultado
      kanban_count = CustomAttributeDefinition.where(is_kanban: true).count
      
      puts "\n✅ Migração concluída com sucesso!"
      puts "📈 #{updated_count} atributos atualizados"
      puts "🏷️  Total de atributos Kanban: #{kanban_count}"
      
      # Mostrar estatísticas finais
      puts "\n📊 Estatísticas finais:"
      puts "  - Atributos Kanban: #{CustomAttributeDefinition.kanban_attributes.count}"
      puts "  - Atributos não-Kanban: #{CustomAttributeDefinition.non_kanban_attributes.count}"
      puts "  - Total de atributos: #{CustomAttributeDefinition.count}"
      
    rescue => e
      puts "\n❌ Erro durante a migração: #{e.message}"
      puts "📝 Backtrace: #{e.backtrace.first(5).join("\n")}"
      raise e
    end
  end
  
  desc 'Rollback Kanban migration (mark all as non-Kanban)'
  task rollback_kanban_migration: :environment do
    puts "🔄 Iniciando rollback da migração Kanban..."
    
    kanban_attributes = CustomAttributeDefinition.where(is_kanban: true)
    puts "📊 Encontrados #{kanban_attributes.count} atributos Kanban"
    
    if kanban_attributes.count == 0
      puts "✅ Nenhum atributo Kanban encontrado. Nada para fazer."
      return
    end
    
    print "\n⚠️  Tem certeza que deseja marcar todos os atributos como não-Kanban? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "❌ Rollback cancelado pelo usuário."
      return
    end
    
    begin
      updated_count = kanban_attributes.update_all(is_kanban: false)
      puts "\n✅ Rollback concluído!"
      puts "📈 #{updated_count} atributos marcados como não-Kanban"
      
    rescue => e
      puts "\n❌ Erro durante rollback: #{e.message}"
      raise e
    end
  end
  
  desc 'Show Kanban attributes status'
  task kanban_status: :environment do
    puts "📊 Status dos Atributos Kanban"
    puts "=" * 40
    
    total = CustomAttributeDefinition.count
    kanban = CustomAttributeDefinition.where(is_kanban: true).count
    non_kanban = CustomAttributeDefinition.where(is_kanban: false).count
    
    puts "Total de atributos: #{total}"
    puts "Atributos Kanban: #{kanban}"
    puts "Atributos não-Kanban: #{non_kanban}"
    
    if kanban > 0
      puts "\n🏷️  Atributos Kanban:"
      CustomAttributeDefinition.kanban_attributes.each do |attr|
        puts "  - #{attr.attribute_display_name} (#{attr.attribute_key})"
      end
    end
  end
end
