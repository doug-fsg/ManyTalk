# frozen_string_literal: true

class NullifyFormSubmissionsOnContactDelete < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :form_submissions, :contacts
    add_foreign_key :form_submissions, :contacts, on_delete: :nullify
  end
end
