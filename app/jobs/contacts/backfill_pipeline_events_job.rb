# frozen_string_literal: true

module Contacts
  class BackfillPipelineEventsJob < ApplicationJob
    queue_as :low

    def perform(account_id = nil)
      scope = ContactPipelinePosition.includes(:contact, :pipeline)
      scope = scope.joins(:contact).where(contacts: { account_id: account_id }) if account_id.present?

      scope.find_each do |position|
        backfill_position(position)
      end
    end

    private

    def backfill_position(position)
      return unless position.pipeline&.is_kanban?
      return if position.contact.blank?

      if position.contact_pipeline_events.none?
        ContactPipelineEvent.create!(
          account_id: position.contact.account_id,
          contact_id: position.contact_id,
          contact_pipeline_position_id: position.id,
          pipeline_id: position.pipeline_id,
          event_type: 'entered',
          to_stage_id: position.stage_id,
          occurred_at: position.created_at || Time.current,
          metadata: { backfilled: true }
        )
      end

      backfill_win_lost(position)
    end

    def backfill_win_lost(position)
      win_lost = position.metadata&.dig('win_lost') || position.metadata&.dig(:win_lost)
      return if win_lost.blank?

      status = (win_lost['status'] || win_lost[:status]).to_s
      event_type = status == 'won' ? 'won' : 'lost'
      return if position.contact_pipeline_events.exists?(event_type: event_type)

      occurred_at = parse_time(win_lost['date'] || win_lost[:date]) || position.updated_at || Time.current

      ContactPipelineEvent.create!(
        account_id: position.contact.account_id,
        contact_id: position.contact_id,
        contact_pipeline_position_id: position.id,
        pipeline_id: position.pipeline_id,
        event_type: event_type,
        to_stage_id: position.stage_id,
        occurred_at: occurred_at,
        metadata: {
          win_lost_notes: win_lost['notes'] || win_lost[:notes],
          deal_value: position.deal_value&.to_f,
          backfilled: true
        }.compact
      )
    end

    def parse_time(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
