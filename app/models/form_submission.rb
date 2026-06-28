# frozen_string_literal: true

class FormSubmission < ApplicationRecord
  belongs_to :account_form, counter_cache: :form_submissions_count
  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true

  validates :account_id, presence: true
  validates :account_form_id, presence: true
  validates :payload, presence: true
end
