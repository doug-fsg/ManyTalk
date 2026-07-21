import { computed } from 'vue';
import { useStoreGetters } from 'dashboard/composables/store';
import {
  getPipelinePosition,
  getWinLostStatus,
  getDealValue,
  getEnteredAt,
  getStage,
  getAssignee,
} from '../../crm/utils/pipelinePositionsHelper';
import {
  buildKanbanDeepLink,
  readLastPipelineId,
} from '../../crm/utils/crmNavigationHelper';

export function useContactCrmContext(contactRef, accountIdRef) {
  const getters = useStoreGetters();

  const kanbanPipelines = computed(() => {
    const attributes = getters['attributes/getAttributes'].value || [];
    return attributes.filter(attribute => attribute.is_kanban);
  });

  const pipelinePositions = computed(
    () => contactRef.value?.pipeline_positions || []
  );

  const resolvedPipelineId = computed(() => {
    const storedId = readLastPipelineId();
    if (storedId && pipelinePositions.value.some(p => p.pipeline_id === storedId)) {
      return storedId;
    }

    if (pipelinePositions.value.length === 1) {
      return pipelinePositions.value[0].pipeline_id;
    }

    const firstKanbanPosition = pipelinePositions.value.find(position =>
      kanbanPipelines.value.some(pipeline => pipeline.id === position.pipeline_id)
    );

    return firstKanbanPosition?.pipeline_id || pipelinePositions.value[0]?.pipeline_id || null;
  });

  const primaryPipeline = computed(() => {
    if (!resolvedPipelineId.value) return null;
    return (
      kanbanPipelines.value.find(
        pipeline => pipeline.id === resolvedPipelineId.value
      ) || null
    );
  });

  const primaryPosition = computed(() => {
    if (!contactRef.value || !resolvedPipelineId.value) return null;
    return getPipelinePosition(contactRef.value, resolvedPipelineId.value);
  });

  const primaryStage = computed(() => {
    if (!contactRef.value || !resolvedPipelineId.value) return null;
    return getStage(contactRef.value, resolvedPipelineId.value);
  });

  const primaryDealValue = computed(() => {
    if (!contactRef.value || !resolvedPipelineId.value) return null;
    return getDealValue(contactRef.value, resolvedPipelineId.value);
  });

  const primaryAssignee = computed(() => {
    if (!contactRef.value || !resolvedPipelineId.value) return null;
    return getAssignee(contactRef.value, resolvedPipelineId.value);
  });

  const primaryWinLost = computed(() => {
    if (!contactRef.value || !resolvedPipelineId.value) return null;
    return getWinLostStatus(contactRef.value, resolvedPipelineId.value);
  });

  const enteredAt = computed(() => {
    if (!contactRef.value || !resolvedPipelineId.value) return null;
    return getEnteredAt(contactRef.value, resolvedPipelineId.value);
  });

  const hasPipeline = computed(() => Boolean(primaryPosition.value));

  const kanbanDeepLink = computed(() => {
    if (!hasPipeline.value || !accountIdRef.value || !contactRef.value?.id) {
      return null;
    }

    return buildKanbanDeepLink(accountIdRef.value, {
      contactId: contactRef.value.id,
      pipelineId: resolvedPipelineId.value,
    });
  });

  const stageColor = computed(() => {
    const pipeline = primaryPipeline.value;
    const stageName = primaryStage.value;
    if (!pipeline?.attribute_values || !stageName) return '#6B7280';

    const stages = Array.isArray(pipeline.attribute_values)
      ? pipeline.attribute_values
      : pipeline.attribute_values?.stages || [];

    const match = stages.find(stage => {
      if (typeof stage === 'string') return stage === stageName;
      return (
        stage?.name === stageName ||
        stage?.id === stageName ||
        stage?.key === stageName
      );
    });

    if (match && typeof match === 'object') {
      return match.color || '#6B7280';
    }

    return '#6B7280';
  });

  return {
    kanbanPipelines,
    pipelinePositions,
    resolvedPipelineId,
    primaryPipeline,
    primaryPosition,
    primaryStage,
    primaryDealValue,
    primaryAssignee,
    primaryWinLost,
    enteredAt,
    hasPipeline,
    kanbanDeepLink,
    stageColor,
  };
}
