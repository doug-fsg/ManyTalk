import AvailabilityStatus from '../AvailabilityStatus.vue';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import VTooltip from 'v-tooltip';
import WootButton from 'dashboard/components/ui/WootButton.vue';
import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import WootDropdownHeader from 'shared/components/ui/dropdown/DropdownHeader.vue';
import WootDropdownDivider from 'shared/components/ui/dropdown/DropdownDivider.vue';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import i18n from 'dashboard/i18n';

const i18nInstance = createI18n({ legacy: true, locale: 'en', messages: i18n });

describe('AvailabilityStatus', () => {
  const currentAvailability = 'online';
  const currentAccountId = '1';
  const currentUserAutoOffline = false;
  let store = null;
  let actions = null;
  let availabilityStatus = null;

  beforeEach(() => {
    actions = {
      updateAvailability: vi.fn(() => Promise.resolve()),
    };

    store = createStore({
      actions,
      modules: {
        auth: {
          getters: {
            getCurrentUserAvailability: () => currentAvailability,
            getCurrentAccountId: () => currentAccountId,
            getCurrentUserAutoOffline: () => currentUserAutoOffline,
          },
        },
      },
    });

    availabilityStatus = mount(AvailabilityStatus, {
      global: {
        plugins: [store, i18nInstance, [VTooltip, { defaultHtml: false }]],
        components: {
          'woot-button': WootButton,
          'woot-dropdown-header': WootDropdownHeader,
          'woot-dropdown-menu': WootDropdownMenu,
          'woot-dropdown-divider': WootDropdownDivider,
          'woot-dropdown-item': WootDropdownItem,
          'fluent-icon': FluentIcon,
        },
        stubs: { WootSwitch: { template: '<button />' } },
      },
    });
  });

  it('dispatches an action when user changes status', async () => {
    await availabilityStatus;
    availabilityStatus
      .findAll('.status-change--dropdown-button')
      .at(2)
      .trigger('click');

    expect(actions.updateAvailability).toBeCalledWith(
      expect.any(Object),
      { availability: 'offline', account_id: currentAccountId },
      undefined
    );
  });
});
