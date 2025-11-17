class AddPositionToContactPipelinePositions < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_pipeline_positions, :position, :integer, default: 0, null: false
    
    # Adicionar índice para ordenação eficiente por pipeline e stage
    add_index :contact_pipeline_positions, [:pipeline_id, :stage_id, :position], 
              name: 'idx_contact_pipeline_positions_pipeline_stage_position'
    
    # Atualizar posições existentes baseado em created_at para manter ordem atual
    execute <<-SQL
      UPDATE contact_pipeline_positions
      SET position = subquery.row_number
      FROM (
        SELECT id, 
               ROW_NUMBER() OVER (PARTITION BY pipeline_id, stage_id ORDER BY created_at ASC) as row_number
        FROM contact_pipeline_positions
      ) AS subquery
      WHERE contact_pipeline_positions.id = subquery.id;
    SQL
  end
end

