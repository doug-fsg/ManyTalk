/* eslint arrow-body-style: 0 */
import { frontendURL } from '../../../helper/URLHelper';
import CrmWrapper from './components/teste.vue';
export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/kanban'),
      component: CrmWrapper,
      props: {},
      children: [
        {
          path: '',
          name: 'crm_wrapper',
          meta: { permissions: ['administrator'] },
          // redirect: 'list',
        },
        {
          path: 'list',
          name: 'crm_home',
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};