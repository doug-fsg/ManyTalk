# frozen_string_literal: true

class AddTriggerEventNameToWorkflows < ActiveRecord::Migration[7.0]
  def up
    add_column :workflows, :trigger_event_name, :string
    add_index :workflows,
              %i[account_id active trigger_event_name],
              name: 'index_workflows_on_account_active_trigger_event',
              where: 'active = true'

    backfill_trigger_event_names
  end

  def down
    remove_index :workflows, name: 'index_workflows_on_account_active_trigger_event'
    remove_column :workflows, :trigger_event_name
  end

  private

  def backfill_trigger_event_names
    say_with_time 'Backfilling workflow trigger_event_name' do
      Workflow.reset_column_information
      Workflow.find_each do |workflow|
        event_name = workflow.trigger_node&.dig('data', 'event_name')
        workflow.update_column(:trigger_event_name, event_name) if event_name.present?
      end
    end
  end
end
