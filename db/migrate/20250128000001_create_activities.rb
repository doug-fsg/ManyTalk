class CreateActivities < ActiveRecord::Migration[7.0]
  def up
    unless table_exists?(:activities)
      create_table :activities do |t|
        t.references :account, null: false, foreign_key: true
        t.references :user, null: false, foreign_key: true
        t.references :assignee, foreign_key: { to_table: :users }, null: true
        t.string :activity_type, null: false
        t.string :title, null: false
        t.text :description
        t.string :status, default: 'pending'
        t.datetime :scheduled_at, null: false
        t.references :contact_pipeline_position, foreign_key: true, null: true, index: false
        t.references :contact, foreign_key: true, null: true
        t.references :conversation, foreign_key: true, null: true, index: false
        t.text :message_content

        t.timestamps
      end
    end

    # Criar índices apenas se não existirem
    add_index :activities, [:account_id, :status] unless index_exists?(:activities, [:account_id, :status])
    add_index :activities, [:account_id, :scheduled_at] unless index_exists?(:activities, [:account_id, :scheduled_at])
    add_index :activities, [:account_id, :assignee_id] unless index_exists?(:activities, [:account_id, :assignee_id])
    add_index :activities, [:contact_pipeline_position_id] unless index_exists?(:activities, [:contact_pipeline_position_id])
    add_index :activities, [:conversation_id] unless index_exists?(:activities, [:conversation_id])
  end

  def down
    drop_table :activities if table_exists?(:activities)
  end
end

