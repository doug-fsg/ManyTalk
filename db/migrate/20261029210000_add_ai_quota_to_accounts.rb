# frozen_string_literal: true

class AddAiQuotaToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :ai_credit_limit, :decimal, precision: 16, scale: 4
    add_column :accounts, :ai_credits_used, :decimal, precision: 16, scale: 4, null: false, default: 0
  end
end
