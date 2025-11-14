class AddKanbanIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # Índice GIN para additional_attributes.kanban
    # Este índice ajuda em queries que acessam dados do kanban dentro de additional_attributes
    # Exemplo: additional_attributes->'kanban'->'pipeline_id'->'stage_tracking'
    unless index_exists?(:contacts, 'idx_contacts_additional_attrs_kanban')
      add_index :contacts,
        "(additional_attributes->'kanban')",
        name: 'idx_contacts_additional_attrs_kanban',
        using: :gin,
        algorithm: :concurrently
    end

    # Nota: O índice GIN em custom_attributes já existe (index_contacts_on_custom_attributes)
    # Não precisamos criar outro índice aqui

    # Índice composto para account_id + custom_attributes (para queries filtradas por account)
    # Este índice ajuda quando filtramos por account_id E custom_attributes
    unless index_exists?(:contacts, 'idx_contacts_account_custom_attrs')
      # O índice em account_id já existe, mas podemos criar um índice funcional
      # que combina account_id com a presença de custom_attributes não vazios
      add_index :contacts,
        [:account_id],
        name: 'idx_contacts_account_custom_attrs',
        where: "custom_attributes != '{}'::jsonb",
        algorithm: :concurrently
    end

    puts "✅ Índices do Kanban criados com sucesso!"
    puts "   - idx_contacts_additional_attrs_kanban: Índice GIN para additional_attributes.kanban"
    puts "   - idx_contacts_account_custom_attrs: Índice parcial para account_id com custom_attributes"
  end

  def down
    if index_exists?(:contacts, 'idx_contacts_additional_attrs_kanban')
      remove_index :contacts, name: 'idx_contacts_additional_attrs_kanban', algorithm: :concurrently
    end

    if index_exists?(:contacts, 'idx_contacts_account_custom_attrs')
      remove_index :contacts, name: 'idx_contacts_account_custom_attrs', algorithm: :concurrently
    end

    puts "✅ Índices do Kanban removidos"
  end
end

