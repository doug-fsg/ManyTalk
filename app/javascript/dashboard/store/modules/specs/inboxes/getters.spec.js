import { getters } from '../../inboxes';
import inboxList from './fixtures';

describe('#getters', () => {
  it('getInboxes', () => {
    const state = {
      records: inboxList,
    };
    expect(getters.getInboxes(state)).toEqual(inboxList);
  });

  it('getWebsiteInboxes', () => {
    const state = { records: inboxList };
    expect(getters.getWebsiteInboxes(state).length).toEqual(3);
  });

  it('getTwilioInboxes', () => {
    const state = { records: inboxList };
    expect(getters.getTwilioInboxes(state).length).toEqual(1);
  });

  it('getSMSInboxes', () => {
    const state = { records: inboxList };
    expect(getters.getSMSInboxes(state).length).toEqual(2);
  });

  it('dialogFlowEnabledInboxes', () => {
    const state = { records: inboxList };
    expect(getters.dialogFlowEnabledInboxes(state).length).toEqual(6);
  });

  it('getInbox', () => {
    const state = {
      records: inboxList,
    };
    expect(getters.getInbox(state)(1)).toEqual({
      id: 1,
      channel_id: 1,
      name: 'Test FacebookPage 1',
      channel_type: 'Channel::FacebookPage',
      avatar_url: 'random_image.png',
      page_id: '12345',
      widget_color: null,
      website_token: null,
      enable_auto_assignment: true,
    });
  });

  it('getUIFlags', () => {
    const state = {
      uiFlags: {
        isFetching: true,
        isFetchingItem: false,
        isCreating: false,
        isUpdating: false,
        isDeleting: false,
      },
    };
    expect(getters.getUIFlags(state)).toEqual({
      isFetching: true,
      isFetchingItem: false,
      isCreating: false,
      isUpdating: false,
      isDeleting: false,
    });
  });

  describe('getFilteredWhatsAppTemplates', () => {
    it('returns only sendable approved templates', () => {
      const state = {
        records: [
          {
            id: 1,
            channel_type: 'Channel::Whatsapp',
            message_templates: [
              {
                name: 'auth_template',
                status: 'approved',
                category: 'AUTHENTICATION',
                components: [{ type: 'BODY', text: 'Code {{1}}' }],
              },
              {
                name: 'marketing_template',
                status: 'approved',
                category: 'MARKETING',
                components: [{ type: 'BODY', text: 'Hello {{1}}' }],
              },
              {
                name: 'pending_template',
                status: 'pending',
                components: [{ type: 'BODY', text: 'Pending' }],
              },
            ],
          },
        ],
      };

      const result = getters.getFilteredWhatsAppTemplates(state)(1);
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('marketing_template');
    });
  });
});
