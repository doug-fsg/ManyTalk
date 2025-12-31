import { frontendURL } from '../../../../helper/URLHelper';

const SettingsContent = () => import('../Wrapper.vue');
const Index = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/announcements'),
      component: SettingsContent,
      props: {
        headerTitle: 'Anúncios',
        icon: 'megaphone',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'announcements_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: 'list',
        },
        {
          path: 'list',
          name: 'announcements_settings',
          meta: {
            permissions: ['administrator'],
          },
          component: Index,
        },
      ],
    },
  ],
};

