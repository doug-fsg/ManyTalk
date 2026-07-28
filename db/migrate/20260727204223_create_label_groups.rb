class CreateLabelGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :label_groups do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :label_groups, [:account_id, :name], unique: true

    add_reference :labels, :label_group, null: true, foreign_key: { on_delete: :nullify }, index: true
  end
end
