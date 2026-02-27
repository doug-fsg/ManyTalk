import { frontendURL } from '../../../helper/URLHelper';
import ActivitiesIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/activities'),
      component: ActivitiesIndex,
      name: 'activities_view',
      meta: {
        permissions: ['administrator', 'agent'],
      },
    },
  ],
};
