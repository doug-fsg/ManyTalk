# frozen_string_literal: true

class AddSubmissionsCountToAccountForms < ActiveRecord::Migration[7.0]
  def change
    add_column :account_forms, :form_submissions_count, :integer, default: 0, null: false
    add_index :account_forms, :form_submissions_count

    # Backfill existing counts
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE account_forms
          SET form_submissions_count = (
            SELECT COUNT(*) FROM form_submissions
            WHERE form_submissions.account_form_id = account_forms.id
          )
        SQL
      end
    end
  end
end
