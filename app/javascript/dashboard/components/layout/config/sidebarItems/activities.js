import { frontendURL } from '../../../../helper/URLHelper';

const activities = accountId => ({
  parentNav: 'activities',
  routes: ['activities_view'],
  menuItems: [
    {
      icon: 'calendar-clock',
      label: 'ACTIVITIES',
      key: 'activities',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/activities`),
      toStateName: 'activities_view',
    },
  ],
});

export default activities;
