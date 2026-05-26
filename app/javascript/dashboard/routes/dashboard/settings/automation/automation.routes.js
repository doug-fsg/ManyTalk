import { frontendURL } from '../../../../helper/URLHelper';
import { requireWorkflowsFeature } from '../../../../helper/workflowsFeatureGuard';

const SettingsWrapper = () => import('../SettingsWrapper.vue');
const AutomationHub = () => import('./AutomationHub.vue');
const Automation = () => import('./Index.vue');
const WorkflowsIndex = () => import('../workflows/WorkflowsIndex.vue');
const WorkflowEditorWrapper = () => import('../workflows/WorkflowEditorWrapper.vue');
const WorkflowEditor = () => import('../workflows/WorkflowEditor.vue');

const agentPermissions = ['administrator', 'agent'];

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/automation'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: 'list',
        },
        {
          path: 'list',
          component: AutomationHub,
          children: [
            {
              path: '',
              name: 'automation_list',
              component: Automation,
              meta: {
                permissions: agentPermissions,
              },
            },
            {
              path: 'workflows',
              name: 'workflows_list',
              component: WorkflowsIndex,
              beforeEnter: requireWorkflowsFeature,
              meta: {
                permissions: agentPermissions,
              },
            },
          ],
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/automation'),
      component: WorkflowEditorWrapper,
      children: [
        {
          path: 'workflows/new',
          name: 'workflows_new',
          component: WorkflowEditor,
          beforeEnter: requireWorkflowsFeature,
          meta: {
            permissions: agentPermissions,
          },
        },
        {
          path: 'workflows/:workflowId/edit',
          name: 'workflows_edit',
          component: WorkflowEditor,
          beforeEnter: requireWorkflowsFeature,
          meta: {
            permissions: agentPermissions,
          },
        },
      ],
    },
  ],
};
