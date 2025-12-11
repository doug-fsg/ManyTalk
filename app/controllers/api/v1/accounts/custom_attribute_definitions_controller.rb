class Api::V1::Accounts::CustomAttributeDefinitionsController < Api::V1::Accounts::BaseController
  before_action :fetch_custom_attributes_definitions, except: [:create]
  before_action :fetch_custom_attribute_definition, only: [:show, :update, :destroy]
  DEFAULT_ATTRIBUTE_MODEL = 'conversation_attribute'.freeze

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
    payload = params.require(:custom_attribute_definition).permit(
      :attribute_display_name,
      :attribute_description,
      :attribute_display_type,
      :attribute_key,
      :attribute_model,
      :regex_pattern,
      :regex_cue,
      :is_kanban,
      attribute_values: {}
    )
    
    # Processar attribute_values para Kanban
    if payload[:attribute_values].is_a?(Hash) && @custom_attribute_definition&.is_kanban
      # Formato esperado: { stages: { "nome": { color } }, permissions: {...} }
      stages = payload[:attribute_values]['stages'] || payload[:attribute_values][:stages] || {}
      permissions = payload[:attribute_values]['permissions'] || payload[:attribute_values][:permissions] || {}
      
      # Se stages vier como array, converter para objeto usando nome como chave
      if stages.is_a?(Array)
        stages_hash = {}
        stages.each do |stage|
          if stage.is_a?(Hash)
            name = stage['name'] || stage[:name]
            color = stage['color'] || stage[:color]
            stages_hash[name] = { 'color' => color } if name
          end
        end
        stages = stages_hash
      end
      
      payload[:attribute_values] = {
        'stages' => stages,
        'permissions' => permissions
      }
    end
    
    payload
  end

  def permitted_params
    params.permit(:id, :filter_type, :attribute_model)
  end
end
