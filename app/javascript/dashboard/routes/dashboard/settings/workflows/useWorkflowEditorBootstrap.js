/** Shared Vuex bootstrap for workflow editor — avoids duplicate API calls per panel. */
let bootstrapPromise = null;

const WORKFLOW_EDITOR_DISPATCHES = [
  'agents/get',
  'teams/get',
  'labels/get',
  'attributes/get',
  'inboxes/get',
  'campaigns/get',
  'contacts/get',
  'accountForms/get',
];

export function ensureWorkflowEditorBootstrapped(store) {
  if (!bootstrapPromise) {
    bootstrapPromise = Promise.all(
      WORKFLOW_EDITOR_DISPATCHES.map(action => store.dispatch(action))
    ).catch(error => {
      bootstrapPromise = null;
      throw error;
    });
  }
  return bootstrapPromise;
}

export function resetWorkflowEditorBootstrap() {
  bootstrapPromise = null;
}
