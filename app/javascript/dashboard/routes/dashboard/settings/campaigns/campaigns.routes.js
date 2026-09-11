import { frontendURL } from '../../../../helper/URLHelper';
import { CAMPAIGN_ROUTE_PERMISSIONS } from '../../../../constants/permissions';

const SettingsContent = () => import('../Wrapper.vue');
const Index = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/campaigns'),
      component: SettingsContent,
      props: {
        headerTitle: 'CAMPAIGN.ONGOING.HEADER',
        icon: 'arrow-swap',
      },
      children: [
        {
          path: '',
          redirect: 'one_off',
        },
        {
          path: 'ongoing',
          name: 'ongoing_campaigns',
          meta: {
            permissions: CAMPAIGN_ROUTE_PERMISSIONS,
          },
          component: Index,
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/campaigns'),
      component: SettingsContent,
      props: {
        headerTitle: 'CAMPAIGN.ONE_OFF.HEADER',
        icon: 'sound-source',
      },
      children: [
        {
          path: 'one_off',
          name: 'one_off',
          meta: {
            permissions: CAMPAIGN_ROUTE_PERMISSIONS,
          },
          component: Index,
        },
      ],
    },
  ],
};