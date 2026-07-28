# frozen_string_literal: true

# == Schema Information
#
# Table name: form_submissions
#
#  id              :bigint           not null, primary key
#  ip_address      :string
#  payload         :jsonb            not null
#  user_agent      :string
#  utm             :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_form_id :bigint           not null
#  account_id      :bigint           not null
#  contact_id      :bigint
#  conversation_id :bigint
#
# Indexes
#
#  index_form_submissions_on_account_form_id                 (account_form_id)
#  index_form_submissions_on_account_form_id_and_created_at  (account_form_id,created_at)
#  index_form_submissions_on_account_id                      (account_id)
#  index_form_submissions_on_contact_id                      (contact_id)
#  index_form_submissions_on_conversation_id                 (conversation_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_form_id => account_forms.id)
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => nullify
#  fk_rails_...  (conversation_id => conversations.id)
#
class FormSubmission < ApplicationRecord
  belongs_to :account_form, counter_cache: :form_submissions_count
  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true

  validates :account_id, presence: true
  validates :account_form_id, presence: true
  validates :payload, presence: true
end
