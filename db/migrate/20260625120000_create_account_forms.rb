# frozen_string_literal: true

class CreateAccountForms < ActiveRecord::Migration[7.0]
  def change
    create_table :account_forms do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :definition, null: false, default: {}
      t.jsonb :branding, null: false, default: {}
      t.jsonb :settings, null: false, default: {}
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :account_forms, [:account_id, :slug], unique: true
    add_index :account_forms, [:account_id, :status]

    create_table :form_submissions do |t|
      t.references :account_form, null: false, foreign_key: true, index: true
      t.references :account, null: false, foreign_key: true, index: true
      t.references :contact, foreign_key: true, index: true
      t.references :conversation, foreign_key: true, index: true
      t.jsonb :payload, null: false, default: {}
      t.jsonb :utm, null: false, default: {}
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :form_submissions, [:account_form_id, :created_at]
  end
end
