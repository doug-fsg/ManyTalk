import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import VTooltip from 'v-tooltip';
import Button from 'dashboard/components/buttons/Button.vue';
import i18n from 'dashboard/i18n';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import MoreActions from '../MoreActions.vue';

vi.mock('shared/helpers/mitt', () => ({
  emitter: {
    emit: vi.fn(),
    on: vi.fn(),
    off: vi.fn(),
  },
}));

import { emitter } from 'shared/helpers/mitt';

const i18nInstance = createI18n({ legacy: true, locale: 'en', messages: i18n });

const mockEmitter = { emit: vi.fn(), on: vi.fn(), off: vi.fn() };

describe('MoveActions', () => {
  let currentChat = { id: 8, muted: false };
  let muteConversation = null;
  let unmuteConversation = null;
  let store = null;
  let moreActions = null;

  beforeEach(() => {
    muteConversation = vi.fn(() => Promise.resolve());
    unmuteConversation = vi.fn(() => Promise.resolve());

    store = createStore({
      state: { authenticated: true, currentChat },
      modules: {
        conversations: { actions: { muteConversation, unmuteConversation } },
      },
      getters: { getSelectedChat: () => currentChat },
    });

    moreActions = mount(MoreActions, {
      global: {
        plugins: [store, i18nInstance, VTooltip],
        components: {
          'fluent-icon': FluentIcon,
          'woot-button': Button,
        },
        mocks: { $emitter: mockEmitter },
        stubs: {
          WootModal: { template: '<div><slot/></div>' },
          WootModalHeader: { template: '<div><slot/></div>' },
        },
      },
    });
  });

  describe('muting discussion', () => {
    it('triggers "muteConversation"', async () => {
      await moreActions.find('button:first-child').trigger('click');

      expect(muteConversation).toBeCalledWith(
        expect.any(Object),
        currentChat.id,
        undefined
      );
    });

    it('shows alert', async () => {
      await moreActions.find('button:first-child').trigger('click');

      expect(emitter.emit).toBeCalledWith('newToastMessage', {
        message:
          'This contact is blocked successfully. You will not be notified of any future conversations.',
        action: null,
      });
    });
  });

  describe('unmuting discussion', () => {
    beforeEach(() => {
      currentChat.muted = true;
    });

    it('triggers "unmuteConversation"', async () => {
      await moreActions.find('button:first-child').trigger('click');

      expect(unmuteConversation).toBeCalledWith(
        expect.any(Object),
        currentChat.id,
        undefined
      );
    });

    it('shows alert', async () => {
      await moreActions.find('button:first-child').trigger('click');

      expect(emitter.emit).toBeCalledWith('newToastMessage', {
        message: 'This contact is unblocked successfully.',
        action: null,
      });
    });
  });
});
