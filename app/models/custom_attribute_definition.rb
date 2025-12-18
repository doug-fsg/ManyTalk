# == Schema Information
#
# Table name: custom_attribute_definitions
#
#  id                     :bigint           not null, primary key
#  attribute_description  :text
#  attribute_display_name :string
#  attribute_display_type :integer          default("text")
#  attribute_key          :string
#  attribute_model        :integer          default("conversation_attribute")
#  attribute_values       :jsonb
#  default_value          :integer
#  is_kanban              :boolean          default(FALSE), not null
#  regex_cue              :string
#  regex_pattern          :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint
#
# Indexes
#
#  attribute_key_model_index                         (attribute_key,attribute_model,account_id) UNIQUE
#  index_custom_attribute_definitions_on_account_id  (account_id)
#  index_custom_attribute_definitions_on_is_kanban   (is_kanban)
#
class CustomAttributeDefinition < ApplicationRecord
  scope :with_attribute_model, ->(attribute_model) { attribute_model.presence && where(attribute_model: attribute_model) }
  scope :kanban_attributes, -> { where(is_kanban: true) }
  scope :non_kanban_attributes, -> { where(is_kanban: false) }
  
  validates :attribute_display_name, presence: true

  validates :attribute_key,
            presence: true,
            uniqueness: { scope: [:account_id, :attribute_model] }

  validates :attribute_display_type, presence: true
  validates :attribute_model, presence: true

  enum attribute_model: { conversation_attribute: 0, contact_attribute: 1 }
  enum attribute_display_type: { text: 0, number: 1, currency: 2, percent: 3, link: 4, date: 5, list: 6, checkbox: 7, file: 8 }

  belongs_to :account
  has_many :contact_pipeline_positions, foreign_key: 'pipeline_id', dependent: :destroy
  
  after_update :update_widget_pre_chat_custom_fields
  after_destroy :sync_widget_pre_chat_custom_fields

  # Métodos de permissão para Kanban
  def user_permission(user)
    return :admin if user_admin?(user)
    
    permissions_hash = get_permissions_hash
    permission = permissions_hash[user.id.to_s]
    
    # Supervisor tem permissões de admin no pipeline
    return :admin if permission == 'supervisor'
    
    return permission.to_sym if permission.present?
    
    # Sem acesso se não estiver na lista
    :none
  end

  def can_view?(user)
    permission = user_permission(user)
    [:admin, :editor, :viewer].include?(permission)
  end

  def can_edit?(user)
    permission = user_permission(user)
    [:admin, :editor].include?(permission)
  end

  def set_user_permission(user_id, level)
    return false unless ['viewer', 'editor', 'supervisor'].include?(level.to_s)
    
    ensure_attribute_values_is_hash
    self.attribute_values['permissions'] ||= {}
    self.attribute_values['permissions'][user_id.to_s] = level.to_s
    save
  end

  def remove_user_permission(user_id)
    ensure_attribute_values_is_hash
    return false unless self.attribute_values['permissions']
    
    self.attribute_values['permissions'].delete(user_id.to_s)
    save
  end

  def users_with_permissions
    return [] unless account.present?
    
    account.users.map do |user|
      account_user = user.account_users.find_by(account_id: account_id)
      {
        id: user.id,
        name: user.name,
        email: user.email,
        role: account_user&.role,
        permission: user_permission(user),
        is_custom: get_permissions_hash.key?(user.id.to_s)
      }
    end
  end

  private

  def user_admin?(user)
    account_user = user.account_users.find_by(account_id: account_id)
    account_user&.administrator?
  end

  def get_permissions_hash
    ensure_attribute_values_is_hash
    self.attribute_values['permissions'] || {}
  end

  def ensure_attribute_values_is_hash
    # Converter array legado para objeto {stages: [...], permissions: {}}
    if self.attribute_values.is_a?(Array)
      self.attribute_values = {
        'stages' => self.attribute_values,
        'permissions' => {}
      }
    elsif self.attribute_values.nil?
      self.attribute_values = {
        'stages' => [],
        'permissions' => {}
      }
    elsif !self.attribute_values.key?('permissions')
      # Se já é hash mas não tem permissions, adicionar
      stages = self.attribute_values.is_a?(Hash) ? (self.attribute_values['stages'] || self.attribute_values.values) : []
      self.attribute_values = {
        'stages' => stages,
        'permissions' => {}
      }
    end
  end

  def sync_widget_pre_chat_custom_fields
    ::Inboxes::SyncWidgetPreChatCustomFieldsJob.perform_later(account, attribute_key)
  end

  def update_widget_pre_chat_custom_fields
    ::Inboxes::UpdateWidgetPreChatCustomFieldsJob.perform_later(account, self)
  end
end
