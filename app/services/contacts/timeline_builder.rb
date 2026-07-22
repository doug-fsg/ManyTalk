# frozen_string_literal: true

module Contacts
  class TimelineBuilder
    EVENT_TYPES = %w[
      contact_created
      form_submission
      pipeline_entered
      pipeline_stage_changed
      pipeline_reopened
      deal_won
      deal_lost
      activity
      note
      conversation_started
    ].freeze

    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 100

    def initialize(contact:, params: {})
      @contact = contact
      @params = params
    end

    def perform
      events = []
      events.concat(contact_created_events)
      events.concat(form_submission_events)
      events.concat(pipeline_events)
      events.concat(activity_events)
      events.concat(note_events)
      events.concat(conversation_events)

      events = filter_by_types(events)
      events.sort_by! { |event| event[:occurred_at] }.reverse!

      paginate(events)
    end

    private

    def contact_created_events
      return [] if @contact.created_at.blank?

      [
        build_event(
          id: "contact_created-#{@contact.id}",
          type: 'contact_created',
          occurred_at: @contact.created_at,
          meta: {
            contact_id: @contact.id,
            contact_name: @contact.name
          }
        )
      ]
    end

    def form_submission_events
      @contact.form_submissions
              .includes(:account_form)
              .order(created_at: :desc)
              .map do |submission|
        build_event(
          id: "form_submission-#{submission.id}",
          type: 'form_submission',
          occurred_at: submission.created_at,
          meta: {
            submission_id: submission.id,
            account_form_id: submission.account_form_id,
            account_form_name: submission.account_form&.name,
            account_form_slug: submission.account_form&.slug,
            conversation_id: submission.conversation_id,
            utm: submission.utm || {}
          }
        )
      end
    end

    def pipeline_events
      persisted = pipeline_event_records
      return persisted if persisted.any?

      legacy_pipeline_events
    end

    def pipeline_event_records
      @contact.contact_pipeline_events
             .includes(:user, contact_pipeline_position: [:assignee, :pipeline])
             .order(occurred_at: :desc)
             .map do |record|
        pipeline_name = record.contact_pipeline_position&.pipeline&.attribute_display_name ||
                        "Pipeline #{record.pipeline_id}"
        position = record.contact_pipeline_position
        base_meta = {
          contact_pipeline_event_id: record.id,
          contact_pipeline_position_id: record.contact_pipeline_position_id,
          pipeline_id: record.pipeline_id,
          pipeline_name: pipeline_name,
          stage_id: record.to_stage_id || position&.stage_id,
          from_stage_id: record.from_stage_id,
          to_stage_id: record.to_stage_id,
          deal_value: record.metadata['deal_value'] || position&.deal_value&.to_f,
          assignee_id: position&.assignee_id,
          assignee_name: position&.assignee&.available_name || position&.assignee&.name,
          user_id: record.user_id,
          user_name: record.user&.available_name || record.user&.name,
          win_lost_notes: record.metadata['win_lost_notes'],
          previous_status: record.metadata['previous_status']
        }.compact

        build_event(
          id: "contact_pipeline_event-#{record.id}",
          type: map_pipeline_event_type(record.event_type),
          occurred_at: record.occurred_at,
          meta: base_meta
        )
      end
    end

    def map_pipeline_event_type(event_type)
      {
        'entered' => 'pipeline_entered',
        'stage_changed' => 'pipeline_stage_changed',
        'won' => 'deal_won',
        'lost' => 'deal_lost',
        'win_lost_cleared' => 'pipeline_reopened'
      }[event_type] || event_type
    end

    def legacy_pipeline_events
      @contact.contact_pipeline_positions
             .includes(:assignee, pipeline: [])
             .flat_map do |position|
        pipeline_name = position.pipeline&.attribute_display_name || "Pipeline #{position.pipeline_id}"
        base_meta = pipeline_meta(position, pipeline_name)
        events = [
          build_event(
            id: "pipeline_entered-#{position.id}",
            type: 'pipeline_entered',
            occurred_at: position.created_at,
            meta: base_meta
          )
        ]

        stage_at = position.entered_at || position.created_at
        if position.entered_at.present? && (position.entered_at - position.created_at).abs > 2.seconds
          events << build_event(
            id: "pipeline_stage-#{position.id}",
            type: 'pipeline_stage_changed',
            occurred_at: stage_at,
            meta: base_meta
          )
        end

        win_lost = position.metadata&.dig('win_lost') || position.metadata&.dig(:win_lost)
        if win_lost.present?
          status = (win_lost['status'] || win_lost[:status]).to_s
          event_type = status == 'won' ? 'deal_won' : 'deal_lost'
          occurred_at = parse_time(win_lost['date'] || win_lost[:date]) || position.updated_at

          events << build_event(
            id: "#{event_type}-#{position.id}",
            type: event_type,
            occurred_at: occurred_at,
            meta: base_meta.merge(
              win_lost_status: status,
              win_lost_notes: win_lost['notes'] || win_lost[:notes],
              deal_value: position.deal_value&.to_f
            )
          )
        end

        events
      end
    end

    def activity_events
      contact_activities.flat_map { |activity| build_activity_timeline_events(activity) }
    end

    def contact_activities
      position_ids = @contact.contact_pipeline_positions.pluck(:id)

      scope = Activity.where(account_id: @contact.account_id)
                      .includes(:assignee, :user)

      scope =
        if position_ids.any?
          scope.where(
            'activities.contact_id = :contact_id OR activities.contact_pipeline_position_id IN (:position_ids)',
            contact_id: @contact.id,
            position_ids: position_ids
          )
        else
          scope.where(contact_id: @contact.id)
        end

      scope.order(scheduled_at: :desc)
    end

    def build_activity_timeline_events(activity)
      base_meta = activity_timeline_meta(activity)

      if activity.status == 'completed'
        completed_at = activity.completed_at || activity.updated_at
        [
          build_event(
            id: "activity_completed-#{activity.id}",
            type: 'activity',
            occurred_at: completed_at,
            meta: base_meta.merge(
              timeline_moment: 'completed',
              completed_at: completed_at.iso8601
            )
          )
        ]
      else
        [
          build_event(
            id: "activity-#{activity.id}",
            type: 'activity',
            occurred_at: activity.scheduled_at,
            meta: base_meta.merge(timeline_moment: 'scheduled')
          )
        ]
      end
    end

    def activity_timeline_meta(activity)
      {
        activity_id: activity.id,
        activity_type: activity.activity_type,
        status: activity.status,
        title: activity.title,
        description: activity.description,
        scheduled_at: activity.scheduled_at&.iso8601,
        assignee_id: activity.assignee_id,
        assignee_name: activity.assignee&.available_name || activity.assignee&.name,
        user_name: activity.user&.available_name || activity.user&.name,
        conversation_id: activity.conversation_id,
        contact_pipeline_position_id: activity.contact_pipeline_position_id
      }
    end

    def note_events
      @contact.notes
              .includes(:user)
              .order(created_at: :desc)
              .map do |note|
        build_event(
          id: "note-#{note.id}",
          type: 'note',
          occurred_at: note.created_at,
          meta: {
            note_id: note.id,
            content: note.content,
            user_id: note.user_id,
            user_name: note.user&.available_name || note.user&.name
          }
        )
      end
    end

    def conversation_events
      @contact.conversations
              .includes(:inbox)
              .order(created_at: :desc)
              .limit(50)
              .map do |conversation|
        build_event(
          id: "conversation_started-#{conversation.id}",
          type: 'conversation_started',
          occurred_at: conversation.created_at,
          meta: {
            conversation_id: conversation.display_id || conversation.id,
            conversation_internal_id: conversation.id,
            inbox_id: conversation.inbox_id,
            inbox_name: conversation.inbox&.name,
            status: conversation.status
          }
        )
      end
    end

    def pipeline_meta(position, pipeline_name)
      meta = {
        contact_pipeline_position_id: position.id,
        pipeline_id: position.pipeline_id,
        pipeline_name: pipeline_name,
        stage_id: position.stage_id,
        deal_value: position.deal_value&.to_f,
        entered_at: position.entered_at&.iso8601,
        assignee_id: position.assignee_id,
        assignee_name: position.assignee&.available_name || position.assignee&.name
      }
      meta.compact
    end

    def build_event(id:, type:, occurred_at:, meta:)
      {
        id: id,
        type: type,
        occurred_at: occurred_at.iso8601,
        meta: meta
      }
    end

    def parse_time(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def filter_by_types(events)
      types = @params[:types]
      return events if types.blank?

      allowed = Array(types).flat_map { |value| value.to_s.split(',') }.map(&:strip).reject(&:blank?)
      return events if allowed.empty?

      events.select { |event| allowed.include?(event[:type].to_s) }
    end

    def paginate(events)
      per_page = [@params[:per_page].to_i, MAX_PER_PAGE].min
      per_page = DEFAULT_PER_PAGE if per_page <= 0
      page = [@params[:page].to_i, 1].max
      count = events.size
      total_pages = (count.to_f / per_page).ceil
      total_pages = 1 if total_pages.zero?
      offset = (page - 1) * per_page

      {
        events: events.slice(offset, per_page),
        count: count,
        current_page: page,
        total_pages: total_pages
      }
    end
  end
end
