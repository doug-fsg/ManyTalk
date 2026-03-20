import { frontendURL } from '../../../../helper/URLHelper';

const campaigns = accountId => ({
  parentNav: 'campaigns',
  routes: ['one_off', 'ongoing_campaigns'],
  menuItems: [
    {
      key: 'oneOffCampaigns',
      icon: 'sound-source',
      label: 'ONE_OFF',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/one_off`),
      toStateName: 'one_off',
    },
    {
      icon: 'arrow-swap',
      label: 'ONGOING',
      key: 'ongoingCampaigns',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/ongoing`),
      toStateName: 'ongoing_campaigns',
    },
  ],
});

export default campaigns;
