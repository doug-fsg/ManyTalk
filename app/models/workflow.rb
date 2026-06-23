# frozen_string_literal: true

# == Schema Information
#
# Table name: workflows
#
#  id                 :bigint           not null, primary key
#  active             :boolean          default(FALSE), not null
#  description        :text
#  graph              :jsonb            not null
#  name               :string           not null
#  trigger_event_name :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  created_by_id      :bigint
#  updated_by_id      :bigint
#
# Indexes
#
#  index_workflows_on_account_active_trigger_event  (account_id,active,trigger_event_name) WHERE (active = true)
#  index_workflows_on_account_id                    (account_id)
#  index_workflows_on_account_id_and_active         (account_id,active)
#  index_workflows_on_created_by_id                 (created_by_id)
#  index_workflows_on_updated_by_id                 (updated_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (updated_by_id => users.id)
#
class Workflow < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  has_many :workflow_enrollments, dependent: :destroy_async

  validates :name, presence: true
  validates :account_id, presence: true
  validates :graph, presence: true

  before_save :sync_trigger_event_name

  scope :active, -> { where(active: true) }
  scope :for_trigger_event, ->(event_name) { active.where(trigger_event_name: event_name) }

  def settings
    graph['settings'].presence || Workflows::Constants::DEFAULT_SETTINGS
  end

  def trigger_node
    (graph['nodes'] || []).find { |n| n['type'] == 'trigger' }
  end

  def trigger_event_name
    trigger_node&.dig('data', 'event_name')
  end

  def find_node(node_id)
    (graph['nodes'] || []).find { |n| n['id'] == node_id }
  end

  def outgoing_edges(node_id)
    (graph['edges'] || []).select { |e| e['source'] == node_id }
  end

  def sync_trigger_event_name
    self.trigger_event_name = trigger_node&.dig('data', 'event_name')
  end

  def next_node_id(node_id, source_handle: nil)
    outs = outgoing_edges(node_id)
    edge = if source_handle.present?
             outs.find { |e| e['sourceHandle'] == source_handle }
           else
             outs.first
           end
    edge&.dig('target')
  end

  def conflicting_automation_names
    event = trigger_event_name
    return [] if event.blank?

    account.automation_rules
           .active
           .where(event_name: event)
           .limit(10)
           .pluck(:name)
  end
end
