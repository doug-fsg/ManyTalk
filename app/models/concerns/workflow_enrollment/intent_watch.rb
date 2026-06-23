# frozen_string_literal: true

module WorkflowEnrollment::IntentWatch
  extend ActiveSupport::Concern

  SEEN_NORMALIZED_CAP = 20

  def intent_watch_active?
    return false unless waiting?

    watch = (context || {})['intent_watch']
    watch.present? && watch['node_id'].present?
  end

  def intent_watch
    (context || {})['intent_watch'] || {}
  end

  def set_intent_watch!(node_id:, baseline_at:, deadline_at:, intent_key:, intent_description: nil)
    # Mutual exclusivity: clearing reply_watch prevents both watches from coexisting.
    watch = {
      'node_id' => node_id,
      'intent_key' => intent_key,
      'baseline_at' => baseline_at.iso8601(6),
      'deadline_at' => deadline_at.iso8601(6),
      'classification_in_flight' => false,
      'seen_normalized' => [],
      'last_classification' => nil
    }
    watch['intent_description'] = intent_description if intent_description.present?

    update!(
      context: (context || {}).except('reply_watch').merge('intent_watch' => watch)
    )
  end

  def clear_intent_watch!
    return unless (context || {}).key?('intent_watch')

    update!(context: (context || {}).except('intent_watch'))
  end

  def intent_watch_classification_in_flight?
    intent_watch['classification_in_flight'] == true
  end

  def set_intent_classification_in_flight!(value)
    watch = (context || {})['intent_watch']
    return unless watch.present?

    updated_watch = watch.merge('classification_in_flight' => value)
    update!(context: (context || {}).merge('intent_watch' => updated_watch))
  end

  def record_intent_classification!(message_id:, matched:, skipped: false, reason: nil)
    watch = (context || {})['intent_watch']
    return unless watch.present?

    updated_watch = watch.merge(
      'classification_in_flight' => false,
      'last_classification' => {
        'message_id' => message_id,
        'matched' => matched,
        'skipped' => skipped,
        'reason' => reason,
        'at' => Time.current.iso8601(6)
      }.compact
    )
    update!(context: (context || {}).merge('intent_watch' => updated_watch))
  end

  def add_seen_normalized!(normalized_content)
    watch = (context || {})['intent_watch']
    return unless watch.present?

    seen = Array(watch['seen_normalized'])
    seen = seen.last(SEEN_NORMALIZED_CAP - 1) if seen.size >= SEEN_NORMALIZED_CAP
    seen << normalized_content

    updated_watch = watch.merge('seen_normalized' => seen)
    update!(context: (context || {}).merge('intent_watch' => updated_watch))
  end

  def seen_normalized_content
    Array(intent_watch['seen_normalized'])
  end

  def last_classified_message_id
    intent_watch.dig('last_classification', 'message_id')
  end

  def intent_matches_message?(message)
    return false if message.blank? || message.activity? || message.private?
    return false if (message.content_attributes || {})['workflow_id'].present?

    message.incoming? && message.sender_type == 'Contact'
  end

  def intent_watch_baseline_at
    time_str = intent_watch['baseline_at']
    Time.zone.parse(time_str) if time_str.present?
  end
end
