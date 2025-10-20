class Api::V1::Accounts::AnnouncementsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, except: [:data]

  # 🔒 MUDANÇA: Movido de tmp/ para storage/ (evita perda de dados)
  JSON_PATH = Rails.root.join('storage', 'announcements', 'data.json')
  BACKUP_PATH = Rails.root.join('storage', 'announcements', 'backups')
  MEDIA_PATH = Rails.root.join('public', 'announcements', 'media')

  def index
    render json: read_json
  end

  def data
    # Retorna apenas anúncios que devem estar visíveis agora
    data = read_json
    data['announcements'] = filter_active_announcements(data['announcements'])
    render json: data
  end

  def create
    # ✅ VALIDAÇÕES
    validation_error = validate_params
    return render json: { error: validation_error }, status: :unprocessable_entity if validation_error

    data = read_json
    
    # Gerar ID automático a partir do título PT-BR
    generated_id = generate_id(params[:title_pt_BR], data['announcements'])
    
    announcement = {
      id: generated_id,
      title: build_translations(:title),
      description: build_translations(:description),
      media_url: params[:media_url],
      target_roles: params[:target_roles] || [],
      published_at: params[:published_at] || Time.current.iso8601,
      active: params[:active] == true || params[:active] == 'true',
      # 🆕 NOVOS CAMPOS: Agendamento e Expiração
      scheduled_at: params[:scheduled_at].presence,
      expires_at: params[:expires_at].presence,
      created_at: Time.current.iso8601,
      created_by: current_user.id
    }

    data['announcements'] << announcement
    write_json(data)

    render json: { success: true, announcement: announcement }
  rescue StandardError => e
    Rails.logger.error "Error creating announcement: #{e.message}"
    render json: { error: 'Erro ao criar anúncio' }, status: :internal_server_error
  end

  def update
    # ✅ VALIDAÇÕES
    validation_error = validate_params
    return render json: { error: validation_error }, status: :unprocessable_entity if validation_error

    data = read_json
    
    announcement_index = data['announcements'].find_index { |a| a['id'] == params[:id] }
    return render json: { error: 'Announcement not found' }, status: 404 unless announcement_index

    existing = data['announcements'][announcement_index]

    # Se é um reset, atualiza a data de publicação
    published_at = if params[:reset_views] == true || params[:reset_views] == 'true'
                     Time.current.iso8601 # Nova data para forçar re-exibição
                   else
                     params[:published_at] || existing['published_at'] # Mantém ou atualiza
                   end

    updated_announcement = {
      id: params[:id], # ID não muda
      title: build_translations(:title),
      description: build_translations(:description),
      media_url: params[:media_url],
      target_roles: params[:target_roles] || [],
      published_at: published_at,
      active: params[:active] == true || params[:active] == 'true',
      # 🆕 NOVOS CAMPOS: Agendamento e Expiração
      scheduled_at: params[:scheduled_at].presence,
      expires_at: params[:expires_at].presence,
      # Mantém campos de auditoria
      created_at: existing['created_at'] || Time.current.iso8601,
      created_by: existing['created_by'],
      updated_at: Time.current.iso8601,
      updated_by: current_user.id
    }

    data['announcements'][announcement_index] = updated_announcement
    write_json(data)

    render json: { success: true, announcement: updated_announcement }
  rescue StandardError => e
    Rails.logger.error "Error updating announcement: #{e.message}"
    render json: { error: 'Erro ao atualizar anúncio' }, status: :internal_server_error
  end

  def destroy
    data = read_json
    
    announcement = data['announcements'].find { |a| a['id'] == params[:id] }
    return render json: { error: 'Announcement not found' }, status: 404 unless announcement

    data['announcements'].reject! { |a| a['id'] == params[:id] }
    write_json(data)

    render json: { success: true }
  rescue StandardError => e
    Rails.logger.error "Error deleting announcement: #{e.message}"
    render json: { error: 'Erro ao excluir anúncio' }, status: :internal_server_error
  end

  private

  # ✅ VALIDAÇÕES
  def validate_params
    return 'Título em PT-BR é obrigatório' if params[:title_pt_BR].blank?
    return 'Descrição em PT-BR é obrigatória' if params[:description_pt_BR].blank?
    return 'Pelo menos um role deve ser selecionado' if params[:target_roles].blank? || params[:target_roles].empty?
    
    # Validar roles válidos
    valid_roles = %w[administrator agent]
    invalid_roles = params[:target_roles] - valid_roles
    return "Roles inválidos: #{invalid_roles.join(', ')}" if invalid_roles.any?

    # Validar datas (se fornecidas)
    if params[:scheduled_at].present?
      begin
        Time.parse(params[:scheduled_at])
      rescue ArgumentError
        return 'Data de agendamento inválida'
      end
    end

    if params[:expires_at].present?
      begin
        expires = Time.parse(params[:expires_at])
        scheduled = params[:scheduled_at].present? ? Time.parse(params[:scheduled_at]) : Time.current
        return 'Data de expiração deve ser posterior à data de agendamento' if expires <= scheduled
      rescue ArgumentError
        return 'Data de expiração inválida'
      end
    end

    nil # Sem erros
  end

  # 🆕 FILTRAR ANÚNCIOS ATIVOS (considera agendamento e expiração)
  def filter_active_announcements(announcements)
    now = Time.current
    
    announcements.map do |announcement|
      # Se não está ativo, não altera
      next announcement unless announcement['active']

      # Verificar se está agendado para o futuro
      if announcement['scheduled_at'].present?
        scheduled_time = Time.parse(announcement['scheduled_at'])
        if now < scheduled_time
          # Ainda não deve aparecer
          announcement['active'] = false
        end
      end

      # Verificar se expirou
      if announcement['expires_at'].present?
        expires_time = Time.parse(announcement['expires_at'])
        if now >= expires_time
          # Já expirou - desativar permanentemente
          announcement['active'] = false
          # 🔄 Atualizar no arquivo (opcional - para economizar processamento)
          # update_announcement_in_file(announcement['id'], { 'active' => false })
        end
      end

      announcement
    end
  end

  def generate_id(title, existing_announcements)
    # Criar slug a partir do título com transliteração
    base_slug = I18n.transliterate(title.to_s)
                     .downcase
                     .gsub(/[^a-z0-9\s-]/, '') # Remove caracteres especiais
                     .gsub(/\s+/, '-')         # Espaços viram hífens
                     .gsub(/-+/, '-')          # Remove hífens duplicados
                     .strip
                     .slice(0, 50)             # Limita tamanho
    
    # Adicionar timestamp para garantir unicidade
    timestamp = Time.current.strftime('%Y%m%d')
    slug = "#{base_slug}-#{timestamp}"
    
    # Se já existir, adicionar contador
    counter = 1
    original_slug = slug
    while existing_announcements.any? { |a| a['id'] == slug }
      slug = "#{original_slug}-#{counter}"
      counter += 1
    end
    
    slug
  end

  def build_translations(field)
    {
      pt_BR: params["#{field}_pt_BR"], # Obrigatório
      en: params["#{field}_en"].presence,
      es: params["#{field}_es"].presence,
      pt: params["#{field}_pt"].presence
    }.compact # Remove chaves com valores nil
  end

  def read_json
    return { 'announcements' => [] } unless File.exist?(JSON_PATH)
    
    begin
      JSON.parse(File.read(JSON_PATH))
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parse error: #{e.message}"
      # Tentar restaurar do backup
      restore_from_backup
    end
  end

  # 🔒 LOCK DE ARQUIVO (evita race conditions)
  def write_json(data)
    FileUtils.mkdir_p(JSON_PATH.dirname)
    
    # Criar backup antes de escrever
    create_backup if File.exist?(JSON_PATH)
    
    # Escrever com lock
    File.open(JSON_PATH, File::RDWR | File::CREAT, 0644) do |f|
      f.flock(File::LOCK_EX) # Lock exclusivo
      f.rewind
      f.write(JSON.pretty_generate(data))
      f.flush
      f.truncate(f.pos)
      f.flock(File::LOCK_UN) # Unlock
    end
  rescue StandardError => e
    Rails.logger.error "Error writing JSON: #{e.message}"
    raise
  end

  # 💾 BACKUP AUTOMÁTICO
  def create_backup
    return unless File.exist?(JSON_PATH)
    
    FileUtils.mkdir_p(BACKUP_PATH)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_file = BACKUP_PATH.join("data_#{timestamp}.json")
    
    FileUtils.cp(JSON_PATH, backup_file)
    
    # Manter apenas últimos 10 backups
    cleanup_old_backups
  end

  def cleanup_old_backups
    backups = Dir.glob(BACKUP_PATH.join('*.json')).sort
    backups[0...-10].each { |f| File.delete(f) } if backups.size > 10
  end

  def restore_from_backup
    latest_backup = Dir.glob(BACKUP_PATH.join('*.json')).sort.last
    
    if latest_backup
      Rails.logger.info "Restoring from backup: #{latest_backup}"
      FileUtils.cp(latest_backup, JSON_PATH)
      JSON.parse(File.read(JSON_PATH))
    else
      Rails.logger.error 'No backup available, returning empty data'
      { 'announcements' => [] }
    end
  end
end

