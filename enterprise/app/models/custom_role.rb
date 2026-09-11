# frozen_string_literal: true

class CustomRole < ApplicationRecord
  belongs_to :account
  has_many :account_users, dependent: :nullify

  PERMISSIONS = %w[
    conversation_manage
    conversation_unassigned_manage
    conversation_participating_manage
    contact_manage
    report_manage
    knowledge_base_manage
    workflow_manage
    automation_manage
    form_manage
    crm_manage
    campaign_manage
    billing_manage
  ].freeze

  validates :name, presence: true
  validate :permissions_are_supported

  private

  def permissions_are_supported
    permission_list = Array(permissions)
    errors.add(:permissions, :blank) if permission_list.empty?

    extras = permission_list - PERMISSIONS
    errors.add(:permissions, :invalid) if extras.any?
  end
end
