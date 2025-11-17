# Concern para gerenciar acesso aos dados do Kanban do contato
# Suporta leitura dual: tenta ler da tabela contact_pipeline_positions primeiro,
# faz fallback para JSON se não encontrar
module ContactKanbanData
  extend ActiveSupport::Concern

  # Retorna o stage_id do pipeline (lê da tabela, fallback para JSON)
  def kanban_stage_for_pipeline(pipeline_id)
    # Tentar ler da tabela primeiro
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    return position.stage_id if position&.stage_id.present?

    # Fallback: ler do JSON
    pipeline = account.custom_attribute_definitions.find_by(id: pipeline_id)
    return nil unless pipeline
    
    custom_attributes&.dig(pipeline.attribute_key)
  end

  # Retorna o deal_value do pipeline (lê da tabela, fallback para JSON)
  def kanban_deal_value_for_pipeline(pipeline_id)
    # Tentar ler da tabela primeiro
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    return position.deal_value if position

    # Fallback: ler do JSON
    additional_attributes&.dig('kanban', pipeline_id.to_s, 'deal', 'value')
  end

  # Retorna os metadata do pipeline (lê da tabela, fallback para JSON)
  def kanban_metadata_for_pipeline(pipeline_id)
    # Tentar ler da tabela primeiro
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    return position.metadata if position&.metadata.present?

    # Fallback: ler do JSON
    kanban_data = additional_attributes&.dig('kanban', pipeline_id.to_s)
    return {} unless kanban_data

    {
      'win_lost' => kanban_data['win_lost'],
      'other_data' => kanban_data.except('deal', 'stage_tracking', 'win_lost')
    }.compact
  end

  # Retorna o entered_at do pipeline (lê da tabela, fallback para JSON)
  def kanban_entered_at_for_pipeline(pipeline_id)
    # Tentar ler da tabela primeiro
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    return position.entered_at if position

    # Fallback: ler do JSON
    entered_at_str = additional_attributes&.dig('kanban', pipeline_id.to_s, 'stage_tracking', 'current', 'entered_at')
    return nil unless entered_at_str

    Time.parse(entered_at_str) rescue nil
  end

  # Retorna todos os dados do kanban para um pipeline (lê da tabela, fallback para JSON)
  def kanban_data_for_pipeline(pipeline_id)
    # Tentar ler da tabela primeiro
    position = contact_pipeline_positions.find_by(pipeline_id: pipeline_id)
    
    if position
      return {
        stage_id: position.stage_id,
        deal_value: position.deal_value,
        entered_at: position.entered_at,
        metadata: position.metadata || {}
      }
    end

    # Fallback: ler do JSON
    pipeline = account.custom_attribute_definitions.find_by(id: pipeline_id)
    return nil unless pipeline

    kanban_json = additional_attributes&.dig('kanban', pipeline_id.to_s)
    
    {
      stage_id: custom_attributes&.dig(pipeline.attribute_key),
      deal_value: kanban_json&.dig('deal', 'value'),
      entered_at: parse_entered_at(kanban_json),
      metadata: extract_metadata(kanban_json)
    }
  end

  # Verifica se o contato está em algum pipeline
  def in_pipeline?(pipeline_id)
    kanban_stage_for_pipeline(pipeline_id).present?
  end

  private

  def parse_entered_at(kanban_json)
    entered_at_str = kanban_json&.dig('stage_tracking', 'current', 'entered_at')
    return nil unless entered_at_str

    Time.parse(entered_at_str) rescue nil
  end

  def extract_metadata(kanban_json)
    return {} unless kanban_json

    {
      'win_lost' => kanban_json['win_lost'],
      'other_data' => kanban_json.except('deal', 'stage_tracking', 'win_lost')
    }.compact
  end
end

