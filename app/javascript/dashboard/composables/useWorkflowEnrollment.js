import { ref, onMounted, watch } from 'vue';
import ConversationWorkflowEnrollmentsAPI from '../api/conversationWorkflowEnrollments';

export function useWorkflowEnrollment(conversationId) {
  const enrollment = ref(null);
  const isLoading = ref(false);
  const error = ref(null);

  const fetchActive = async () => {
    if (!conversationId.value) return;
    isLoading.value = true;
    error.value = null;
    try {
      const { data } = await ConversationWorkflowEnrollmentsAPI.getActive(
        conversationId.value
      );
      enrollment.value = data.enrollment || data;
      if (enrollment.value && !enrollment.value.id) enrollment.value = null;
    } catch (e) {
      error.value = e;
      enrollment.value = null;
    } finally {
      isLoading.value = false;
    }
  };

  const start = async (workflowId, startNodeId = null) => {
    error.value = null;
    try {
      const { data } = await ConversationWorkflowEnrollmentsAPI.start(
        conversationId.value,
        { workflowId, startNodeId }
      );
      enrollment.value = data;
      return { success: true };
    } catch (e) {
      error.value = e;
      return { success: false, error: e };
    }
  };

  const pause = async () => {
    if (!enrollment.value) return { success: false };
    try {
      const { data } = await ConversationWorkflowEnrollmentsAPI.pause(
        conversationId.value,
        enrollment.value.id
      );
      enrollment.value = data;
      return { success: true };
    } catch (e) {
      error.value = e;
      return { success: false, error: e };
    }
  };

  const resume = async () => {
    if (!enrollment.value) return { success: false };
    try {
      const { data } = await ConversationWorkflowEnrollmentsAPI.resume(
        conversationId.value,
        enrollment.value.id
      );
      enrollment.value = data;
      return { success: true };
    } catch (e) {
      error.value = e;
      return { success: false, error: e };
    }
  };

  const cancel = async () => {
    if (!enrollment.value) return { success: false };
    try {
      await ConversationWorkflowEnrollmentsAPI.cancel(
        conversationId.value,
        enrollment.value.id
      );
      enrollment.value = null;
      return { success: true };
    } catch (e) {
      error.value = e;
      return { success: false, error: e };
    }
  };

  const jump = async nodeId => {
    if (!enrollment.value) return { success: false };
    try {
      const { data } = await ConversationWorkflowEnrollmentsAPI.jump(
        conversationId.value,
        enrollment.value.id,
        nodeId
      );
      enrollment.value = data;
      return { success: true };
    } catch (e) {
      error.value = e;
      return { success: false, error: e };
    }
  };

  const rebind = async targetConversationId => {
    if (!enrollment.value) return { success: false };
    try {
      const { data } = await ConversationWorkflowEnrollmentsAPI.rebind(
        conversationId.value,
        enrollment.value.id,
        targetConversationId
      );
      enrollment.value = data;
      return { success: true };
    } catch (e) {
      error.value = e;
      return { success: false, error: e };
    }
  };

  onMounted(fetchActive);
  watch(conversationId, fetchActive);

  return {
    enrollment,
    isLoading,
    error,
    fetchActive,
    start,
    pause,
    resume,
    cancel,
    jump,
    rebind,
  };
}
