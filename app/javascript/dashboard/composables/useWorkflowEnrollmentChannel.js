import { onMounted, onUnmounted } from 'vue';
import { emitter } from 'shared/helpers/mitt';

const WORKFLOW_ENROLLMENT_EVENT = 'workflow_enrollment.updated';

export function useWorkflowEnrollmentChannel({ onUpdate }) {
  const handler = payload => {
    if (typeof onUpdate === 'function') onUpdate(payload);
  };

  onMounted(() => {
    emitter.on(WORKFLOW_ENROLLMENT_EVENT, handler);
  });

  onUnmounted(() => {
    emitter.off(WORKFLOW_ENROLLMENT_EVENT, handler);
  });
}
