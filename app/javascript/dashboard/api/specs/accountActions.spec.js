import accountActionsAPI from '../accountActions';
import ApiClient from '../ApiClient';

describe('#ContactsAPI', () => {
  it('creates correct instance', () => {
    expect(accountActionsAPI).toBeInstanceOf(ApiClient);
    expect(accountActionsAPI).toHaveProperty('merge');
    expect(accountActionsAPI).toHaveProperty('mergeConversation');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('#merge', () => {
      accountActionsAPI.merge(1, 2);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/actions/contact_merge',
        {
          base_contact_id: 1,
          mergee_contact_id: 2,
        }
      );
    });

    it('#mergeConversation', () => {
      accountActionsAPI.mergeConversation(10, 20);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/actions/conversation_merge',
        {
          base_conversation_id: 10,
          mergee_conversation_id: 20,
        }
      );
    });
  });
});
