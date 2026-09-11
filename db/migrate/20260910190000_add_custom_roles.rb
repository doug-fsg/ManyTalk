class AddCustomRoles < ActiveRecord::Migration[7.0]
  def up
    unless table_exists?(:custom_roles)
      create_table :custom_roles do |t|
        t.string :name
        t.string :description
        t.references :account, null: false
        t.text :permissions, array: true, default: []
        t.timestamps
      end
    end

    return if column_exists?(:account_users, :custom_role_id)

    add_reference :account_users, :custom_role, optional: true
  end

  def down
    remove_reference :account_users, :custom_role if column_exists?(:account_users, :custom_role_id)
    drop_table :custom_roles if table_exists?(:custom_roles)
  end
end
