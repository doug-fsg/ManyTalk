# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_attendant_runs
#
#  id              :bigint           not null, primary key
#  error_message   :text
#  metadata        :jsonb            not null
#  skip_reason     :string
#  status          :string           not null
#  tokens          :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :integer          not null
#  inbox_id        :integer          not null
#
# Indexes
#
#  index_ai_attendant_runs_on_account_id                 (account_id)
#  index_ai_attendant_runs_on_account_id_and_created_at  (account_id,created_at)
#  index_ai_attendant_runs_on_conversation_id            (conversation_id)
#  index_ai_attendant_runs_on_inbox_id                   (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class AiAttendantRun < ApplicationRecord
  STATUSES = %w[success skipped error handoff].freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :inbox

  validates :status, inclusion: { in: STATUSES }
end
