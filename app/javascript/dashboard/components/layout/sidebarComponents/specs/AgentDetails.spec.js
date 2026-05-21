import AgentDetails from '../AgentDetails.vue';
import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import VTooltip from 'v-tooltip';
import i18n from 'dashboard/i18n';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import WootButton from 'dashboard/components/ui/WootButton.vue';

const i18nInstance = createI18n({ legacy: true, locale: 'en', messages: i18n });

describe('agentDetails', () => {
  const currentUser = {
    name: 'Neymar Junior',
    avatar_url: '',
    availability_status: 'online',
  };
  const currentRole = 'agent';
  let store = null;
  let agentDetails = null;

  beforeEach(() => {
    store = createStore({
      modules: {
        auth: {
          getters: {
            getCurrentUser: () => currentUser,
            getCurrentRole: () => currentRole,
            getCurrentUserAvailability: () => currentUser.availability_status,
          },
        },
      },
    });

    agentDetails = shallowMount(AgentDetails, {
      global: {
        plugins: [store, i18nInstance, [VTooltip, { defaultHtml: false }]],
        components: {
          thumbnail: Thumbnail,
          'woot-button': WootButton,
        },
      },
    });
  });

  it(' the agent status', () => {
    expect(agentDetails.find('thumbnail-stub').vm.status).toBe('online');
  });

  it('agent thumbnail exists', () => {
    const thumbnailComponent = agentDetails.findComponent(Thumbnail);
    expect(thumbnailComponent.exists()).toBe(true);
  });
});
