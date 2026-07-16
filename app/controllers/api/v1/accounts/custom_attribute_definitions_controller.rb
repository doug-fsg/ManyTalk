class Api::V1::Accounts::CustomAttributeDefinitionsController < Api::V1::Accounts::BaseController
  before_action :fetch_custom_attributes_definitions, except: [:create]
  before_action :fetch_custom_attribute_definition, only: [:show, :update, :destroy]
  DEFAULT_ATTRIBUTE_MODEL = 'conversation_attribute'.freeze

  BASE_PAYLOAD_KEYS = %i[
    attribute_display_name
    attribute_description
    attribute_display_type
    attribute_key
    attribute_model
    regex_pattern
    regex_cue
    is_kanban
  ].freeze

  def index; end

  def show; end

  def create
    @custom_attribute_definition = Current.account.custom_attribute_definitions.create!(
      permitted_payload
    )
  end

  def update
    # Verificar se atendente está tentando modificar permissões
    permissions_param = params[:custom_attribute_definition]&.dig(:permissions) || params[:permissions]
    if permissions_param.present? && !Current.user.administrator?
      render json: {
        error: 'Você não tem permissão para modificar permissões do pipeline'
      }, status: :forbidden
      return
    end

    payload = permitted_payload

    # Processar permissões se fornecidas (apenas para administradores)
    if permissions_param.present?
      process_permissions(permissions_param)
    end

    @custom_attribute_definition.update!(payload)
  end

  def destroy
    # Verificar permissões para exclusão de pipelines Kanban
    if @custom_attribute_definition.is_kanban && !Current.user.administrator?
      permission = @custom_attribute_definition.user_permission(Current.user)
      unless permission == :admin
        render json: {
          error: 'Você não tem permissão para excluir este pipeline'
        }, status: :forbidden
        return
      end
    end

    @custom_attribute_definition.destroy!
    head :no_content
  end

  private

  def fetch_custom_attributes_definitions
    @custom_attribute_definitions = Current.account.custom_attribute_definitions.with_attribute_model(permitted_params[:attribute_model])
  end

  def fetch_custom_attribute_definition
    @custom_attribute_definition = Current.account.custom_attribute_definitions.find(permitted_params[:id])
  end

  def process_permissions(permissions_param)
    # Garantir que attribute_values seja um hash
    current_values = @custom_attribute_definition.attribute_values

    if current_values.is_a?(Array)
      # Converter array legado para hash
      @custom_attribute_definition.attribute_values = {
        'stages' => current_values,
        'permissions' => {}
      }
    elsif current_values.nil?
      @custom_attribute_definition.attribute_values = {
        'stages' => [],
        'permissions' => {}
      }
    elsif !current_values.key?('permissions')
      @custom_attribute_definition.attribute_values['permissions'] = {}
    end

    # Atualizar permissões
    @custom_attribute_definition.attribute_values['permissions'] = permissions_param.to_h
    @custom_attribute_definition.save!
  end

  def permitted_payload
    raw_values = params.dig(:custom_attribute_definition, :attribute_values)

    payload = if kanban_attribute?
                if raw_values.is_a?(Array)
                  params.require(:custom_attribute_definition).permit(
                    *BASE_PAYLOAD_KEYS,
                    attribute_values: []
                  )
                else
                  permit_kanban_payload
                end
              else
                permit_standard_payload
              end

    normalize_kanban_attribute_values!(payload) if kanban_attribute?
    payload
  end

  def permit_standard_payload
    params.require(:custom_attribute_definition).permit(
      *BASE_PAYLOAD_KEYS,
      attribute_values: []
    )
  end

  def permit_kanban_payload
    params.require(:custom_attribute_definition).permit(
      *BASE_PAYLOAD_KEYS,
      attribute_values: [
        { stages: {} },
        { permissions: {} },
        { stage_order: [] }
      ]
    )
  end

  def kanban_attribute?
    return @custom_attribute_definition.is_kanban if @custom_attribute_definition

    ActiveModel::Type::Boolean.new.cast(
      params.dig(:custom_attribute_definition, :is_kanban)
    )
  end

  def normalize_kanban_attribute_values!(payload)
    attribute_values = payload[:attribute_values]
    return if attribute_values.blank?

    if attribute_values.is_a?(Array)
      payload[:attribute_values] = build_kanban_attribute_values(
        stages: attribute_values,
        permissions: {},
        stage_order: nil
      )
      return
    end

    return unless attribute_values.is_a?(Hash)

    stages = attribute_values['stages'] || attribute_values[:stages] || {}
    permissions = attribute_values['permissions'] || attribute_values[:permissions] || {}
    stage_order = attribute_values['stage_order'] || attribute_values[:stage_order]

    if stages.is_a?(Array)
      stages_hash = {}
      ordered_names = []

      stages.each do |stage|
        if stage.is_a?(Hash)
          name = stage['name'] || stage[:name]
          color = stage['color'] || stage[:color]
          next unless name

          stages_hash[name] = { 'color' => color }
          ordered_names << name.to_s
        elsif stage.present?
          name = stage.to_s
          stages_hash[name] = { 'color' => nil }
          ordered_names << name
        end
      end

      stages = stages_hash
      stage_order = ordered_names if stage_order.blank?
    end

    payload[:attribute_values] = build_kanban_attribute_values(
      stages: stages,
      permissions: permissions,
      stage_order: stage_order
    )
  end

  def build_kanban_attribute_values(stages:, permissions:, stage_order:)
    stages_hash = if stages.is_a?(Hash)
                    stages.each_with_object({}) do |(name, data), memo|
                      memo[name.to_s] = {
                        'color' => data.is_a?(Hash) ? (data['color'] || data[:color]) : nil
                      }
                    end
                  else
                    build_stages_hash_from_array(Array(stages))
                  end

    normalized_order = Array(stage_order).map(&:to_s).select { |name| stages_hash.key?(name) }
    remaining_names = stages_hash.keys - normalized_order
    normalized_order += remaining_names

    {
      'stages' => stages_hash,
      'permissions' => permissions || {},
      'stage_order' => normalized_order
    }
  end

  def build_stages_hash_from_array(stages)
    stages.each_with_object({}) do |stage, memo|
      if stage.is_a?(Hash)
        name = stage['name'] || stage[:name]
        color = stage['color'] || stage[:color]
        next unless name

        memo[name.to_s] = { 'color' => color }
      elsif stage.present?
        memo[stage.to_s] = { 'color' => nil }
      end
    end
  end

  def permitted_params
    params.permit(:id, :filter_type, :attribute_model)
  end
end
