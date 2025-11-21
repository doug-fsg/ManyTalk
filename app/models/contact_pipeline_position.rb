# == Schema Information
#
# Table name: contact_pipeline_positions
#
#  id          :bigint           not null, primary key
#  contact_id  :bigint           not null
#  pipeline_id :bigint           not null
#  stage_id    :string           not null
#  deal_value  :decimal(10, 2)
#  entered_at  :datetime
#  metadata    :jsonb            default({})
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_contact_pipeline_positions_contact              (contact_id)
#  idx_contact_pipeline_positions_pipeline             (pipeline_id)
#  idx_contact_pipeline_positions_pipeline_stage       (pipeline_id,stage_id)
#  idx_contact_pipeline_positions_unique                (contact_id,pipeline_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (pipeline_id => custom_attribute_definitions.id)
#

class ContactPipelinePosition < ApplicationRecord
  include Events::Types

  belongs_to :contact
  belongs_to :pipeline, class_name: 'CustomAttributeDefinition', foreign_key: 'pipeline_id'

  validates :contact_id, presence: true
  validates :pipeline_id, presence: true
  validates :stage_id, presence: true
  validates :contact_id, uniqueness: { scope: :pipeline_id }

  # Disparar evento CONTACT_UPDATED quando pipeline position é criado, atualizado ou destruído
  # Isso garante sincronização em tempo real entre chat, Kanban, macros e automações
  after_commit :dispatch_contact_updated_event, on: [:create, :update, :destroy]

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
    # attribute_values pode ser array simples de strings ou array de objetos {key: ..., value: ...}
    attribute_values = Array(pipeline.attribute_values)
    
    # Verificar se stage_id existe diretamente no array ou como 'key' em objetos
    # Para kanban, stage_id geralmente corresponde ao 'key' do objeto
    stage_exists = attribute_values.any? do |value|
      if value.is_a?(Hash)
        # Verificar tanto 'key' quanto 'value' para compatibilidade
        value['key'] == stage_id || value[:key] == stage_id || 
        value['value'] == stage_id || value[:value] == stage_id
      else
        value == stage_id
      end
    end
    
    unless stage_exists
      Rails.logger.warn "Stage '#{stage_id}' not found in pipeline #{pipeline_id}. Available: #{attribute_values.inspect}"
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

