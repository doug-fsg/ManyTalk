import {
  getMessagingWindowExpiresAt,
  getMessagingWindowSortScore,
} from '../messagingWindow';

describe('messagingWindow', () => {
  const whatsappInbox = { channel_type: 'Channel::Whatsapp' };
  const now = Math.floor(Date.now() / 1000);

  it('sorts sooner expiry before later expiry', () => {
    const soon = {
      inbox_id: 1,
      last_incoming_message_at: now - 23 * 3600,
    };
    const later = {
      inbox_id: 1,
      last_incoming_message_at: now - 3600,
    };

    expect(getMessagingWindowSortScore(soon, whatsappInbox)).toBeLessThan(
      getMessagingWindowSortScore(later, whatsappInbox)
    );
  });

  it('returns Infinity without last incoming message', () => {
    expect(getMessagingWindowExpiresAt({}, whatsappInbox)).toBe(
      Number.POSITIVE_INFINITY
    );
  });
});
