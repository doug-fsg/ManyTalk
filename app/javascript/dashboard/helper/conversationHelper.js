/**
 * Determines the last non-activity message between store and API messages.
 * @param {Object} messageInStore - The last non-activity message from the store.
 * @param {Object} messageFromAPI - The last non-activity message from the API.
 * @returns {Object} The latest non-activity message.
 */
const getLastNonActivityMessage = (messageInStore, messageFromAPI) => {
  // If both API value and store value for last non activity message
  // are available, then return the latest one.
  if (messageInStore && messageFromAPI) {
    return messageInStore.created_at >= messageFromAPI.created_at
      ? messageInStore
      : messageFromAPI;
  }
  // Otherwise, return whichever is available
  return messageInStore || messageFromAPI;
};

/**
 * Filters out duplicate source messages from an array of messages.
 * @param {Array} messages - The array of messages to filter.
 * @returns {Array} An array of messages without duplicates.
 */
export const filterDuplicateSourceMessages = (messages = []) => {
  const messagesWithoutDuplicates = [];
  // We cannot use Map or any short hand method as it returns the last message with the duplicate ID
  // We should return the message with smaller id when there is a duplicate
  messages.forEach(m1 => {
    if (m1.source_id) {
      const index = messagesWithoutDuplicates.findIndex(
        m2 => m1.source_id === m2.source_id
      );

      if (index < 0) {
        messagesWithoutDuplicates.push(m1);
      }
    } else {
      messagesWithoutDuplicates.push(m1);
    }
  });
  return messagesWithoutDuplicates;
};

/**
 * Retrieves the last message from a conversation, prioritizing non-activity messages.
 * @param {Object} m - The conversation object containing messages.
 * @returns {Object} The last message of the conversation.
 */
export const getLastMessage = m => {
  const lastMessageIncludingActivity = m.messages[m.messages.length - 1];
  const lastNonActivityMessage = m.messages
    .filter(message => message.message_type !== 2)
    .pop();

  return getLastNonActivityMessage(
    lastNonActivityMessage,
    m.last_non_activity_message
  );
};

/**
 * Checks if a conversation is unread based on the last message and user activity.
 * @param {Object} conversation - The conversation object.
 * @param {number} currentUserId - The ID of the current user.
 * @returns {boolean} True if the conversation is unread, false otherwise.
 */
export const isUnreadConversation = (conversation, currentUserId) => {
  const lastMessage = getLastMessage(conversation);
  if (!lastMessage) return false;

  const { sender, created_at: lastMessageTime } = lastMessage;
  const { agent_last_seen_at: agentLastSeenAt } = conversation;

  // If there's no agent last seen time, consider it unread
  if (!agentLastSeenAt) return true;

  // If the last message is from the current user, it's not unread for them
  if (sender && sender.id === currentUserId) return false;

  // Compare timestamps to determine if unread
  return new Date(lastMessageTime) > new Date(agentLastSeenAt);
};

/**
 * Gets the conversation status display information.
 * @param {string} status - The conversation status.
 * @returns {Object} Object containing status display properties.
 */
export const getConversationStatusInfo = status => {
  const statusMap = {
    open: {
      color: 'success',
      label: 'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open',
      icon: 'chat',
    },
    resolved: {
      color: 'secondary',
      label: 'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved',
      icon: 'checkmark-circle',
    },
    pending: {
      color: 'warning',
      label: 'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending',
      icon: 'clock',
    },
    snoozed: {
      color: 'secondary',
      label: 'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed',
      icon: 'snooze',
    },
  };

  return statusMap[status] || statusMap.open;
};

/**
 * Formats conversation timestamp for display.
 * @param {string} timestamp - The timestamp to format.
 * @returns {string} Formatted timestamp string.
 */
export const formatConversationTimestamp = timestamp => {
  if (!timestamp) return '';

  const date = new Date(timestamp);
  const now = new Date();
  const diffInHours = (now - date) / (1000 * 60 * 60);

  if (diffInHours < 24) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  } else if (diffInHours < 168) { // 7 days
    return date.toLocaleDateString([], { weekday: 'short' });
  } else {
    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
  }
};

export { getLastNonActivityMessage };
