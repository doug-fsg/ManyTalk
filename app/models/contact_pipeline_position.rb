# == Schema Information
#
# Table name: contact_pipeline_positions
#
#  id          :bigint           not null, primary key
#  deal_value  :decimal(10, 2)
#  entered_at  :datetime
#  metadata    :jsonb
#  position    :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  assignee_id :bigint
#  contact_id  :bigint           not null
#  pipeline_id :bigint           not null
#  stage_id    :string           not null
#
# Indexes
#
#  idx_contact_pipeline_positions_contact                  (contact_id)
#  idx_contact_pipeline_positions_pipeline                 (pipeline_id)
#  idx_contact_pipeline_positions_pipeline_stage           (pipeline_id,stage_id)
#  idx_contact_pipeline_positions_pipeline_stage_position  (pipeline_id,stage_id,position)
#  idx_contact_pipeline_positions_unique                   (contact_id,pipeline_id) UNIQUE
#  index_contact_pipeline_positions_on_assignee_id         (assignee_id)
#
# Foreign Keys
#
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (pipeline_id => custom_attribute_definitions.id)
#

class ContactPipelinePosition < ApplicationRecord
  include Events::Types

  belongs_to :contact
  belongs_to :pipeline, class_name: 'CustomAttributeDefinition', foreign_key: 'pipeline_id'
  belongs_to :assignee, class_name: 'User', optional: true

  has_many :activities, dependent: :nullify

  validates :contact_id, presence: true
  validates :pipeline_id, presence: true
  validates :stage_id, presence: true
  validates :contact_id, uniqueness: { scope: :pipeline_id }

  # Disparar evento CONTACT_UPDATED quando pipeline position é criado, atualizado ou destruído
  # Isso garante sincronização em tempo real entre chat, Kanban, macros e automações
  after_commit :dispatch_contact_updated_event, on: [:create, :update, :destroy]
  
  # Auto-atribuir dono ao criar card
  before_create :auto_assign_owner_if_new

  scope :for_pipeline, ->(pipeline_id) { where(pipeline_id: pipeline_id) }
  scope :for_stage, ->(stage_id) { where(stage_id: stage_id) }
  scope :for_contact, ->(contact_id) { where(contact_id: contact_id) }
  scope :for_account, ->(account_id) { joins(:contact).where(contacts: { account_id: account_id }) }
  scope :ordered, -> { order(:position, :created_at) }

  # Método helper para atualizar ou criar posição do contato no pipeline
  # Usado por automações, macros e outros serviços
  # Retorna a posição atualizada ou nil em caso de erro
  def self.update_stage(contact, pipeline_id, stage_id, entered_at: nil)
    return nil unless contact.present? && pipeline_id.present? && stage_id.present?

    # Validar que o pipeline existe e é kanban
    pipeline = contact.account.custom_attribute_definitions.find_by(
      id: pipeline_id,
      is_kanban: true
    )
    return nil unless pipeline.present?

    # Validar que o stage existe no pipeline
    # attribute_values pode ser:
    # - Array simples de strings: ["Etapa 1", "Etapa 2"]
    # - Array de objetos: [{name: "Etapa 1", color: "#ff6900"}, ...]
    # - Hash com stages e permissions: {"stages" => [...], "permissions" => {...}}
    stages = extract_stages_from_attribute_values(pipeline.attribute_values)
    
    # Verificar se stage_id existe no array de stages
    stage_exists = stages.any? do |stage|
      if stage.is_a?(Hash)
        # Objeto com name e color: {name: "Etapa 1", color: "#ff6900"}
        stage['name'] == stage_id || stage[:name] == stage_id ||
        stage['id'] == stage_id || stage[:id] == stage_id ||
        stage['key'] == stage_id || stage[:key] == stage_id ||
        stage['value'] == stage_id || stage[:value] == stage_id
      else
        # String simples
        stage.to_s == stage_id.to_s
      end
    end
    
    unless stage_exists
      Rails.logger.warn "Stage '#{stage_id}' not found in pipeline #{pipeline_id}. Available stages: #{stages.inspect}"
      return nil
    end

    # Buscar ou criar posição
    position = find_or_initialize_by(
      contact_id: contact.id,
      pipeline_id: pipeline_id
    )

    # Obter stage anterior para mensagens de atividade
    old_stage_id = position.stage_id if position.persisted?

    # Atualizar atributos
    position.stage_id = stage_id
    position.entered_at = entered_at || position.entered_at || Time.current

    if position.save
      position
    else
      Rails.logger.error "Failed to update pipeline position: #{position.errors.full_messages.join(', ')}"
      nil
    end
  rescue => e
    Rails.logger.error "Error updating pipeline position: #{e.class.name} - #{e.message}"
    nil
  end

  private

  # Extrai o array de stages do attribute_values, lidando com diferentes formatos
  def self.extract_stages_from_attribute_values(attribute_values)
    return [] if attribute_values.nil?
    
    if attribute_values.is_a?(Hash)
      # Formato novo: {"stages" => [...], "permissions" => {...}}
      # Pode ter chave como string ou símbolo
      stages = attribute_values['stages'] || attribute_values[:stages] || 
               attribute_values['values'] || attribute_values[:values] || []
      
      # Se stages é um hash (formato {"Etapa 1" => {color: "#ff6900"}}), converter para array
      if stages.is_a?(Hash)
        stages.map { |name, data| { name: name.to_s, color: data.is_a?(Hash) ? (data['color'] || data[:color]) : nil } }
      else
        Array(stages)
      end
    elsif attribute_values.is_a?(Array)
      # Formato legado: array simples ou array de objetos
      attribute_values
    else
      []
    end
  end

  def auto_assign_owner_if_new
    return if assignee_id.present? # Já tem dono
    return unless new_record? # Só na criação
    
    # Se foi adicionado por usuário manualmente
    if Current.user.present? && Current.user.is_a?(User)
      self.assignee = Current.user
    # Se foi por macro/automação, tentar herdar da conversa
    elsif contact.conversations.any?
      last_conv = contact.conversations.order(updated_at: :desc).first
      self.assignee = last_conv.assignee if last_conv&.assignee.present?
    end
    # Se não conseguir atribuir, fica nil (sem dono)
  end

  def dispatch_contact_updated_event
    return unless contact.present?

    # Recarregar o contato para garantir que pipeline_positions está atualizado
    contact.reload
    
    # Disparar evento CONTACT_UPDATED para sincronização em tempo real
    Rails.configuration.dispatcher.dispatch(
      CONTACT_UPDATED,
      Time.zone.now,
      contact: contact
    )
  rescue => e
    Rails.logger.error "Error dispatching contact updated event: #{e.class.name} - #{e.message}"
  end
end

