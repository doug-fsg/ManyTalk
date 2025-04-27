/* eslint arrow-body-style: 0 */
import { frontendURL } from '../../../helper/URLHelper';
import KanbanAttributes from './components/KanbanAttributes.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/kanban'),
      component: KanbanAttributes,
      props: {},
      children: [
        {
          path: '',
          name: 'kanban_view',
          meta: { permissions: ['administrator', 'agent'] },
        },
      ],
    },
  ],
};
