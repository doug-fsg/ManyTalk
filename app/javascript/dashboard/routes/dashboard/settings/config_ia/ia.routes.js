import { frontendURL } from 'dashboard/helper/URLHelper';

const SettingsContent = () => import('../Wrapper.vue');
const SettingsWrapper = () => import('../SettingsWrapper.vue');
const Index = () => import('./Index.vue');
const Editor = () => import('./Editor.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ia'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'settings_ia',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/ia'),
      component: SettingsContent,
      props: () => {
        return {
          headerTitle: 'AI_ATTENDANT.HEADER',
          icon: 'window-new',
          showBackButton: true,
          backUrl: { name: 'settings_ia' },
        };
      },
      children: [
        {
          path: ':configId/edit',
          name: 'settings_ia_edit',
          component: Editor,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: 'new',
          name: 'settings_ia_new',
          component: Editor,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
