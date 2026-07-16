# Concern para gerenciar acesso aos dados do Kanban do contato.
# Fonte da verdade: contact_pipeline_positions (JSON legado é removido automaticamente).
module ContactKanbanData
  extend ActiveSupport::Concern

  # Retorna o stage_id do pipeline (lê apenas da tabela)
  def kanban_stage_for_pipeline(pipeline_id)
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    position&.stage_id
  end

  # Retorna o deal_value do pipeline (lê apenas da tabela)
  def kanban_deal_value_for_pipeline(pipeline_id)
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    position&.deal_value
  end

  # Retorna os metadata do pipeline (lê apenas da tabela)
  def kanban_metadata_for_pipeline(pipeline_id)
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    position&.metadata || {}
  end

  # Retorna o entered_at do pipeline (lê apenas da tabela)
  def kanban_entered_at_for_pipeline(pipeline_id)
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    position&.entered_at
  end

  # Retorna todos os dados do kanban para um pipeline (lê apenas da tabela)
  def kanban_data_for_pipeline(pipeline_id)
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    return nil unless position

    {
      stage_id: position.stage_id,
      deal_value: position.deal_value,
      entered_at: position.entered_at,
      metadata: position.metadata || {}
    }
  end

  # Verifica se o contato está em algum pipeline
  def in_pipeline?(pipeline_id)
    kanban_stage_for_pipeline(pipeline_id).present?
  end
end

