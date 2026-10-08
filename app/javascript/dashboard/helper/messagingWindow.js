const DEFAULT_WINDOW_HOURS = 24;

export function inboxHasMessagingWindow(inbox) {
  if (!inbox) return false;
  if (inbox.channel_type === 'Channel::Whatsapp') return true;
  if (inbox.channel_type === 'Channel::FacebookPage') return true;
  if (inbox.channel_type === 'Channel::Api') {
    const hours = inbox.additional_attributes?.agent_reply_time_window;
    return hours != null && Number(hours) > 0;
  }
  return false;
}

export function getMessagingWindowHours(inbox) {
  if (!inbox) return DEFAULT_WINDOW_HOURS;
  if (inbox.channel_type === 'Channel::Api') {
    const hours = Number(inbox.additional_attributes?.agent_reply_time_window);
    if (hours > 0) return hours;
  }
  return DEFAULT_WINDOW_HOURS;
}

/** Unix timestamp when the free-reply window closes; +Infinity if not applicable. */
export function getMessagingWindowExpiresAt(conversation, inbox) {
  const lastIncomingAt = conversation?.last_incoming_message_at;
  if (!lastIncomingAt || !inboxHasMessagingWindow(inbox)) {
    return Number.POSITIVE_INFINITY;
  }
  return lastIncomingAt + getMessagingWindowHours(inbox) * 3600;
}

/** Lower = expires sooner (including already expired). */
export function getMessagingWindowSortScore(conversation, inbox) {
  return getMessagingWindowExpiresAt(conversation, inbox);
}
