import { frontendURL } from '../../../../helper/URLHelper';
import {
  requireWorkflowsFeature,
  isWorkflowsFeatureEnabled,
} from '../../../../helper/workflowsFeatureGuard';
import { requireFormsAccess } from '../../../../helper/formsFeatureGuard';
import {
  AUTOMATION_ROUTE_PERMISSIONS,
  FORM_ROUTE_PERMISSIONS,
  WORKFLOW_ROUTE_PERMISSIONS,
} from '../../../../constants/permissions';

const SettingsWrapper = () => import('../SettingsWrapper.vue');
const AutomationHub = () => import('./AutomationHub.vue');
const Automation = () => import('./Index.vue');
const WorkflowsIndex = () => import('../workflows/WorkflowsIndex.vue');
const FormsIndex = () => import('../forms/FormsIndex.vue');
const FormDetail = () => import('../forms/FormDetail.vue');
const WorkflowEditorWrapper = () => import('../workflows/WorkflowEditorWrapper.vue');
const WorkflowEditor = () => import('../workflows/WorkflowEditor.vue');

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
              redirect: to =>
                isWorkflowsFeatureEnabled(to.params.accountId)
                  ? { path: 'workflows' }
                  : { path: 'classic' },
            },
            {
              path: 'classic',
              name: 'automation_list',
              component: Automation,
              meta: {
                permissions: AUTOMATION_ROUTE_PERMISSIONS,
              },
            },
            {
              path: 'workflows',
              name: 'workflows_list',
              component: WorkflowsIndex,
              beforeEnter: requireWorkflowsFeature,
              meta: {
                permissions: WORKFLOW_ROUTE_PERMISSIONS,
              },
            },
            {
              path: 'forms',
              name: 'forms_list',
              component: FormsIndex,
              beforeEnter: requireFormsAccess,
              meta: {
                permissions: FORM_ROUTE_PERMISSIONS,
              },
            },
            {
              path: 'forms/:formId',
              name: 'forms_show',
              component: FormDetail,
              beforeEnter: requireFormsAccess,
              meta: {
                permissions: FORM_ROUTE_PERMISSIONS,
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
            permissions: WORKFLOW_ROUTE_PERMISSIONS,
          },
        },
        {
          path: 'workflows/:workflowId/edit',
          name: 'workflows_edit',
          component: WorkflowEditor,
          beforeEnter: requireWorkflowsFeature,
          meta: {
            permissions: WORKFLOW_ROUTE_PERMISSIONS,
          },
        },
      ],
    },
  ],
};
