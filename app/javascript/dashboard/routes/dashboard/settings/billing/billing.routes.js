import { frontendURL } from '../../../../helper/URLHelper';
import { BILLING_ROUTE_PERMISSIONS } from '../../../../constants/permissions';

const SettingsWrapper = () => import('../SettingsWrapper.vue');
const Index = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/billing'),
      meta: {
        permissions: BILLING_ROUTE_PERMISSIONS,
      },
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'billing_settings_index',
          component: Index,
          meta: {
            permissions: BILLING_ROUTE_PERMISSIONS,
          },
        },
      ],
    },
  ],
};
