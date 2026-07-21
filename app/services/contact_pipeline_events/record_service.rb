# frozen_string_literal: true

module ContactPipelineEvents
  class RecordService
    def initialize(position)
      @position = position
    end

    def perform
      return unless @position.contact.present?
      return unless @position.pipeline&.is_kanban?

      record_entered if @position.previously_new_record?
      record_stage_changed if stage_changed_on_existing_record?
      record_win_lost_changes if @position.saved_change_to_metadata?
    end

    private

    def stage_changed_on_existing_record?
      @position.saved_change_to_stage_id? && !@position.previously_new_record?
    end

    def record_entered
      create_event!(
        event_type: 'entered',
        to_stage_id: @position.stage_id,
        occurred_at: @position.created_at || Time.current
      )
    end

    def record_stage_changed
      from_stage_id, to_stage_id = @position.saved_change_to_stage_id
      return if from_stage_id.to_s == to_stage_id.to_s

      create_event!(
        event_type: 'stage_changed',
        from_stage_id: from_stage_id,
        to_stage_id: to_stage_id,
        occurred_at: @position.entered_at || Time.current
      )
    end

    def record_win_lost_changes
      previous_metadata, current_metadata = @position.saved_change_to_metadata
      previous_win_lost = extract_win_lost(previous_metadata)
      current_win_lost = extract_win_lost(current_metadata)

      if current_win_lost.blank? && previous_win_lost.present?
        create_event!(
          event_type: 'win_lost_cleared',
          from_stage_id: @position.stage_id,
          occurred_at: Time.current,
          metadata: { previous_status: previous_win_lost['status'] }
        )
        return
      end

      return if current_win_lost.blank?

      previous_status = previous_win_lost&.dig('status')
      current_status = current_win_lost['status']
      return if previous_status == current_status

      event_type = current_status == 'won' ? 'won' : 'lost'
      occurred_at = parse_time(current_win_lost['date']) || Time.current

      create_event!(
        event_type: event_type,
        to_stage_id: @position.stage_id,
        occurred_at: occurred_at,
        metadata: {
          win_lost_notes: current_win_lost['notes'],
          deal_value: @position.deal_value&.to_f
        }.compact
      )
    end

    def create_event!(event_type:, occurred_at:, from_stage_id: nil, to_stage_id: nil, metadata: {})
      ContactPipelineEvent.create!(
        account_id: @position.contact.account_id,
        contact_id: @position.contact_id,
        contact_pipeline_position_id: @position.id,
        pipeline_id: @position.pipeline_id,
        event_type: event_type,
        from_stage_id: from_stage_id,
        to_stage_id: to_stage_id,
        user_id: current_user_id,
        occurred_at: occurred_at,
        metadata: metadata
      )
    end

    def current_user_id
      Current.user.is_a?(User) ? Current.user.id : nil
    end

    def extract_win_lost(metadata)
      return nil if metadata.blank?

      value = metadata['win_lost'] || metadata[:win_lost]
      return nil if value.blank?

      {
        'status' => (value['status'] || value[:status]).to_s,
        'date' => value['date'] || value[:date],
        'notes' => value['notes'] || value[:notes]
      }.compact
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
