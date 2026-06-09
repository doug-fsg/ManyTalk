# frozen_string_literal: true

module WorkflowEnrollment::ReplyWatch
  extend ActiveSupport::Concern

  def reply_watch_active?
    return false unless waiting?

    watch = (context || {})['reply_watch']
    watch.present? && watch['node_id'].present?
  end

  def reply_watch
    (context || {})['reply_watch'] || {}
  end

  def set_reply_watch!(node_id:, baseline_at:, deadline_at:, wait_responder: 'contact')
    update!(
      context: (context || {}).merge(
        'reply_watch' => {
          'node_id' => node_id,
          'baseline_at' => baseline_at.iso8601(6),
          'deadline_at' => deadline_at.iso8601(6),
          'wait_responder' => wait_responder
        }
      )
    )
  end

  def clear_reply_watch!
    return unless (context || {}).key?('reply_watch')

    update!(context: (context || {}).except('reply_watch'))
  end

  def contact_replied_since_baseline?
    baseline = reply_baseline_time
    return false if baseline.blank?

    conversation.messages.incoming
                .where('created_at > ?', baseline)
                .where.not("content_attributes ? 'workflow_id'")
                .exists?
  end

  def agent_replied_since_baseline?
    baseline = reply_baseline_time
    return false if baseline.blank?

    conversation.messages.outgoing
                .where(private: false)
                .where('created_at > ?', baseline)
                .where(sender_type: 'User')
                .where.not("content_attributes ? 'workflow_id'")
                .exists?
  end

  def replied_since_baseline?
    case reply_watch['wait_responder'] || 'contact'
    when 'agent'
      agent_replied_since_baseline?
    when 'any'
      contact_replied_since_baseline? || agent_replied_since_baseline?
    else
      contact_replied_since_baseline?
    end
  end

  def reply_matches_message?(message)
    return false if message.blank? || message.activity? || message.private?
    return false if (message.content_attributes || {})['workflow_id'].present?

    case reply_watch['wait_responder'] || 'contact'
    when 'agent'
      message.outgoing? && message.sender_type == 'User'
    when 'any'
      (message.incoming? && message.sender_type == 'Contact') ||
        (message.outgoing? && message.sender_type == 'User')
    else
      message.incoming? && message.sender_type == 'Contact'
    end
  end

  def reply_baseline_time
    watch = reply_watch
    if watch['baseline_at'].present?
      Time.zone.parse(watch['baseline_at'])
    else
      self.class.reply_baseline_for(conversation)
    end
  end

  class << self
    def reply_baseline_for(conversation)
      last_workflow_msg = conversation.messages.outgoing
                                      .where("content_attributes ->> 'workflow_id' IS NOT NULL")
                                      .order(created_at: :desc)
                                      .first
      last_workflow_msg&.created_at || Time.current
    end
  end
end
