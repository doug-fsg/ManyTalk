class AddIsKanbanToCustomAttributeDefinitions < ActiveRecord::Migration[7.0]
  def up
    # Adicionar coluna is_kanban com valor padrão false
    add_column :custom_attribute_definitions, :is_kanban, :boolean, default: false, null: false
    
    # Adicionar índice para melhor performance nas consultas
    add_index :custom_attribute_definitions, :is_kanban
    
    # MIGRAÇÃO SEGURA: Marcar todos os atributos do tipo 'list' e modelo 'contact_attribute'
    # como kanban = true, para manter compatibilidade com o comportamento atual
    # Isso garante que todos os pipelines existentes continuem funcionando
    CustomAttributeDefinition.where(
      attribute_display_type: 'list',
      attribute_model: 'contact_attribute'
    ).update_all(is_kanban: true)
    
    puts "✅ Migração concluída: #{CustomAttributeDefinition.where(is_kanban: true).count} atributos marcados como Kanban"
  end

  def down
    remove_index :custom_attribute_definitions, :is_kanban
    remove_column :custom_attribute_definitions, :is_kanban
  end
end
