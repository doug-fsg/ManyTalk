class CreateContactPipelinePositions < ActiveRecord::Migration[7.0]
  def change
    create_table :contact_pipeline_positions, force: :cascade do |t|
      t.bigint :contact_id, null: false
      t.bigint :pipeline_id, null: false # FK para custom_attribute_definitions.id
      t.string :stage_id, null: false
      t.decimal :deal_value, precision: 10, scale: 2
      t.datetime :entered_at
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index [:contact_id, :pipeline_id], unique: true, name: 'idx_contact_pipeline_positions_unique'
      t.index [:pipeline_id, :stage_id], name: 'idx_contact_pipeline_positions_pipeline_stage'
      t.index [:contact_id], name: 'idx_contact_pipeline_positions_contact'
      t.index [:pipeline_id], name: 'idx_contact_pipeline_positions_pipeline'
    end

    add_foreign_key :contact_pipeline_positions, :contacts, column: :contact_id
    add_foreign_key :contact_pipeline_positions, :custom_attribute_definitions, column: :pipeline_id

    puts "✅ Tabela contact_pipeline_positions criada com sucesso!"
    puts "   Esta tabela será usada como estrutura auxiliar para melhor performance do Kanban"
    puts "   Nota: A tabela está criada mas não está sendo usada ainda - apenas preparação para futuro"
  end
end

