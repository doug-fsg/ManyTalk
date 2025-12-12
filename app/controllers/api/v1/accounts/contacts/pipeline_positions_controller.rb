class Api::V1::Accounts::Contacts::PipelinePositionsController < Api::V1::Accounts::BaseController
  before_action :ensure_pipeline, only: [:stats, :dashboard_stats]
  before_action :ensure_contact, only: [:update, :destroy]
  before_action :check_pipeline_edit_permission, only: [:update, :destroy, :reorder]
  before_action :check_pipeline_view_permission, only: [:stats, :dashboard_stats]

  # Atualizar posição do contato no pipeline
  def update
    position = @contact.contact_pipeline_positions
      .includes(:assignee)
      .find_or_initialize_by(pipeline_id: params[:pipeline_id])

    position.assign_attributes(
      stage_id: params[:stage_id],
      position: params[:position] || position.position || 0
    )

    position.entered_at = params[:entered_at] if params[:entered_at].present?
    position.deal_value = params[:deal_value] if params[:deal_value].present?
    position.metadata = params[:metadata] if params[:metadata].present?
    
    # Permitir trocar dono explicitamente (apenas admin)
    # EXCEÇÃO: Agentes podem atribuir para si mesmos quando o card não tem dono
    # Aceitar null para remover assignee (apenas admin)
    if params.key?(:assignee_id)
      if can_change_assignee?(position, params[:assignee_id])
        position.assignee_id = params[:assignee_id]
      else
        return render json: { error: 'Sem permissão para trocar dono' }, status: :forbidden
      end
    end

    if position.save
      render json: {
        pipeline_id: position.pipeline_id,
        stage_id: position.stage_id,
        position: position.position,
        entered_at: position.entered_at,
        deal_value: position.deal_value,
        metadata: position.metadata || {},
        assignee: position.assignee ? assignee_json(position.assignee) : nil
      }
    else
      render json: { error: position.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Remover contato do pipeline
  def destroy
    position = @contact.contact_pipeline_positions.find_by(pipeline_id: params[:pipeline_id])
    
    if position
      position.destroy
      head :ok
    else
      head :not_found
    end
  end

  # Estatísticas agregadas por stage
  def stats
    pipeline_id = params[:pipeline_id].to_i
    # Usar joins explícito para garantir que funciona corretamente
    positions = ContactPipelinePosition
      .joins(:contact)
      .where(contacts: { account_id: Current.account.id })
      .where(pipeline_id: pipeline_id)

    stage_stats = positions
      .group(:stage_id)
      .select(
        'stage_id',
        'COUNT(*) as count',
        'COALESCE(SUM(deal_value), 0) as total_value'
      )
      .map do |stat|
        {
          stage_id: stat.stage_id,
          count: stat.count,
          total_value: stat.total_value.to_f
        }
      end

    render json: { stage_stats: stage_stats }
  end

  # Estatísticas completas do dashboard
  def dashboard_stats
    pipeline_id = params[:pipeline_id].to_i
    # Usar joins explícito para garantir que funciona corretamente
    # IMPORTANTE: Todos os dados vêm SOMENTE de contact_pipeline_positions (sem JSON de contacts)
    positions_relation = ContactPipelinePosition
      .joins(:contact)
      .where(contacts: { account_id: Current.account.id })
      .where(pipeline_id: pipeline_id)

    # Estatísticas gerais usando SQL
    total_cards = positions_relation.count
    total_value_result = positions_relation.sum(:deal_value)
    total_value = total_value_result.to_f || 0.0

    # Contar por status usando SQL (mais eficiente)
    # Usar JSONB queries para buscar status no metadata
    # Tratar casos onde metadata pode ser NULL ou não ter a estrutura esperada
    # Usar COALESCE para tratar NULLs e verificar se a chave existe
    won_cards = positions_relation.where(
      "COALESCE(metadata->'win_lost'->>'status', '') = ?", 'won'
    ).count
    lost_cards = positions_relation.where(
      "COALESCE(metadata->'win_lost'->>'status', '') = ?", 'lost'
    ).count
    open_cards = total_cards - won_cards - lost_cards

    # Valores por status usando SQL
    won_value_result = positions_relation.where(
      "COALESCE(metadata->'win_lost'->>'status', '') = ?", 'won'
    ).sum(:deal_value)
    won_value = (won_value_result || 0).to_f

    lost_value_result = positions_relation.where(
      "COALESCE(metadata->'win_lost'->>'status', '') = ?", 'lost'
    ).sum(:deal_value)
    lost_value = (lost_value_result || 0).to_f

    open_value = total_value.to_f - won_value - lost_value

    # Taxa de conversão
    total_finalized = won_cards + lost_cards
    win_rate = total_finalized > 0 ? ((won_cards.to_f / total_finalized) * 100).round : 0

    # Tempo médio na etapa (em dias)
    # Calcular em Ruby para evitar problemas com GROUP BY em queries agregadas
    positions_with_time = positions_relation.where.not(entered_at: nil).pluck(:entered_at)
    average_time_days = begin
      if positions_with_time.any?
        now = Time.current
        total_seconds = positions_with_time.sum do |entered_at|
          (now - entered_at).to_i
        end
        avg_seconds = total_seconds.to_f / positions_with_time.count
        (avg_seconds / 86400.0).round
      else
        0
      end
    rescue => e
      Rails.logger.warn "Error calculating average time: #{e.message}"
      0
    end

    # Valor médio do deal usando SQL
    positions_with_value = positions_relation.where('deal_value > 0')
    average_deal_value = if positions_with_value.exists?
      avg_result = positions_with_value.average(:deal_value)
      avg_result ? avg_result.to_f : 0
    else
      0
    end

    # Estatísticas por stage usando SQL (mais eficiente)
    stage_stats = positions_relation
      .group(:stage_id)
      .select(
        'stage_id',
        'COUNT(*) as count',
        'COALESCE(SUM(deal_value), 0) as total_value'
      )
      .map do |stat|
        {
          stage_id: stat.stage_id,
          count: stat.count,
          total_value: stat.total_value.to_f
        }
      end

    render json: {
      total_cards: total_cards,
      total_value: total_value.to_f,
      open_cards: open_cards,
      open_value: open_value.to_f,
      won_cards: won_cards,
      won_value: won_value.to_f,
      lost_cards: lost_cards,
      lost_value: lost_value.to_f,
      win_rate: win_rate,
      average_time_days: average_time_days,
      average_deal_value: average_deal_value,
      stage_stats: stage_stats
    }
  rescue => e
    Rails.logger.error "Error calculating dashboard stats: #{e.class.name} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Retornar erro detalhado em desenvolvimento para debug
    error_message = Rails.env.development? ? e.message : 'Erro ao calcular estatísticas do dashboard'
    render json: { 
      error: error_message,
      details: Rails.env.development? ? e.backtrace.first(5) : nil
    }, status: :internal_server_error
  end

  # Reordenar múltiplas posições
  def reorder
    pipeline_id = params[:pipeline_id].to_i
    positions_data = params[:positions] || []

    ActiveRecord::Base.transaction do
      positions_data.each do |position_data|
        contact_id = position_data[:contact_id] || position_data['contact_id']
        stage_id = position_data[:stage_id] || position_data['stage_id']
        position = position_data[:position] || position_data['position'] || 0
        entered_at = position_data[:entered_at] || position_data['entered_at']
        deal_value = position_data[:deal_value] || position_data['deal_value']
        metadata = position_data[:metadata] || position_data['metadata']

        contact = Current.account.contacts.find_by(id: contact_id)
        next unless contact

        pipeline_position = contact.contact_pipeline_positions.find_or_initialize_by(
          pipeline_id: pipeline_id
        )

        pipeline_position.assign_attributes(
          stage_id: stage_id,
          position: position
        )

        pipeline_position.entered_at = entered_at if entered_at.present?
        pipeline_position.deal_value = deal_value if deal_value.present?
        pipeline_position.metadata = metadata if metadata.present?

        pipeline_position.save!
      end
    end

    head :ok
  rescue => e
    Rails.logger.error "Error reordering pipeline positions: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def ensure_contact
    @contact = Current.account.contacts.find(params[:contact_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Contact not found' }, status: :not_found
  end

  def ensure_pipeline
    @pipeline = Current.account.custom_attribute_definitions.find_by(
      id: params[:pipeline_id],
      is_kanban: true
    )
    
    unless @pipeline
      render json: { error: 'Pipeline not found' }, status: :not_found
    end
  end

  def check_pipeline_edit_permission
    pipeline = Current.account.custom_attribute_definitions.find_by(
      id: params[:pipeline_id],
      is_kanban: true
    )
    
    return unless pipeline
    
    # Admin sempre pode
    return if Current.user.administrator?
    
    # Verificar permissão do pipeline
    permission = pipeline.user_permission(Current.user)
    
    # Admin e Supervisor podem editar qualquer card (sem restrições)
    return if permission == :admin
    
    # Viewer não pode editar
    if permission == :viewer
      render json: { 
        error: 'Você não tem permissão para editar este pipeline' 
      }, status: :forbidden
      return
    end
    
    # Editor pode editar, mas verificar se o card é dele ou sem dono
    if permission == :editor
      position = @contact.contact_pipeline_positions.find_by(
        pipeline_id: params[:pipeline_id]
      )
      
      # Se card tem dono e não é o editor, bloquear
      if position&.assignee_id.present? && position.assignee_id != Current.user.id
        render json: { 
          error: 'Você só pode editar cards que são seus ou que não têm dono' 
        }, status: :forbidden
        return
      end
    end
  end

  def check_pipeline_view_permission
    pipeline = Current.account.custom_attribute_definitions.find_by(
      id: params[:pipeline_id],
      is_kanban: true
    )
    
    unless pipeline&.can_view?(Current.user)
      render json: { 
        error: 'Você não tem permissão para visualizar este pipeline' 
      }, status: :forbidden
    end
  end
  
  def can_change_assignee?(position = nil, new_assignee_id = nil)
    # Administradores sempre podem
    return true if Current.user&.administrator?
    
    # Supervisor tem permissões de admin no pipeline
    pipeline = Current.account.custom_attribute_definitions.find_by(
      id: params[:pipeline_id],
      is_kanban: true
    )
    if pipeline
      permission = pipeline.user_permission(Current.user)
      return true if permission == :admin # Supervisor retorna :admin via user_permission
    end
    
    # EXCEÇÃO: Agentes podem atribuir para si mesmos quando o card não tem dono
    if position && new_assignee_id && Current.user
      # Card não tem dono atual E usuário quer atribuir para si mesmo
      if position.assignee_id.nil? && new_assignee_id == Current.user.id
        return true
      end
    end
    
    false
  end
  
  def assignee_json(user)
    {
      id: user.id,
      name: user.name,
      available_name: user.available_name,
      avatar_url: user.avatar_url,
      thumbnail: user.avatar_url
    }
  end
end

