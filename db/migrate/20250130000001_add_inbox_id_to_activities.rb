class AddInboxIdToActivities < ActiveRecord::Migration[7.0]
  def change
    add_reference :activities, :inbox, foreign_key: true, null: true, index: true
  end
end
