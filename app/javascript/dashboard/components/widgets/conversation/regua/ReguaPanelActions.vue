<template>
  <div class="flex flex-wrap gap-2">
    <template v-if="isPaused">
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="primary"
        :is-loading="isResuming"
        @click="$emit('resume')"
      >
        {{ $t('WORKFLOW.REGUA.RESUME') }}
      </woot-button>
    </template>
    <template v-else>
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="warning"
        :is-loading="isPausing"
        @click="$emit('pause')"
      >
        {{ $t('WORKFLOW.REGUA.PAUSE') }}
      </woot-button>
    </template>
    <woot-button
      size="small"
      variant="smooth"
      color-scheme="alert"
      @click="showCancelModal = true"
    >
      {{ $t('WORKFLOW.REGUA.CANCEL') }}
    </woot-button>

    <div
      v-if="availableStages.length"
      class="flex items-center gap-2 w-full mt-1"
    >
      <label :for="stageSelectId" class="input-label flex-1">
        <span class="sr-only">{{ $t('WORKFLOW.REGUA.SELECT_STAGE') }}</span>
        <select
          :id="stageSelectId"
          v-model="selectedStageId"
          name="jump_stage_id"
          class="w-full mb-0 bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-100 border-slate-75 dark:border-slate-600"
        >
          <option value="">
            {{ $t('WORKFLOW.REGUA.SELECT_STAGE') }}
          </option>
          <option
            v-for="stage in availableStages"
            :key="stage.id"
            :value="stage.id"
          >
            {{ stage.label }}
          </option>
        </select>
      </label>
      <woot-button
        size="small"
        variant="smooth"
        :disabled="!selectedStageId"
        @click="showJumpModal = true"
      >
        {{ $t('WORKFLOW.REGUA.JUMP_CONFIRM') }}
      </woot-button>
    </div>

    <woot-modal
      :show.sync="showCancelModal"
      :on-close="closeCancelModal"
    >
      <div class="h-auto overflow-auto flex flex-col overscroll-contain">
        <woot-modal-header
          :header-title="$t('WORKFLOW.REGUA.CANCEL_MODAL.TITLE')"
          :header-content="$t('WORKFLOW.REGUA.CANCEL_MODAL.DESCRIPTION')"
        />
        <div class="flex flex-row justify-end gap-2 py-4 px-8 w-full">
          <woot-button variant="clear" @click="closeCancelModal">
            {{ $t('COMMON.CANCEL') }}
          </woot-button>
          <woot-button
            color-scheme="alert"
            :is-loading="isCancelling"
            @click="onConfirmCancel"
          >
            {{ $t('WORKFLOW.REGUA.CANCEL_MODAL.CONFIRM') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <woot-modal
      :show.sync="showJumpModal"
      :on-close="closeJumpModal"
    >
      <div class="h-auto overflow-auto flex flex-col overscroll-contain">
        <woot-modal-header
          :header-title="$t('WORKFLOW.REGUA.JUMP_MODAL.TITLE')"
          :header-content="$t('WORKFLOW.REGUA.JUMP_MODAL.DESCRIPTION')"
        />
        <div class="flex flex-row justify-end gap-2 py-4 px-8 w-full">
          <woot-button variant="clear" @click="closeJumpModal">
            {{ $t('COMMON.CANCEL') }}
          </woot-button>
          <woot-button
            color-scheme="primary"
            :is-loading="isJumping"
            @click="onConfirmJump"
          >
            {{ $t('WORKFLOW.REGUA.JUMP_MODAL.CONFIRM') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>
  </div>
</template>

<script setup>
import { ref } from 'vue';

defineProps({
  isPaused: { type: Boolean, default: false },
  isPausing: { type: Boolean, default: false },
  isResuming: { type: Boolean, default: false },
  isCancelling: { type: Boolean, default: false },
  isJumping: { type: Boolean, default: false },
  availableStages: { type: Array, default: () => [] },
});

const emit = defineEmits(['pause', 'resume', 'cancel', 'jump']);

const showCancelModal = ref(false);
const showJumpModal = ref(false);
const selectedStageId = ref('');
const stageSelectId = `fluxo-stage-select-${Math.random().toString(36).slice(2, 8)}`;

const closeCancelModal = () => {
  showCancelModal.value = false;
};

const closeJumpModal = () => {
  showJumpModal.value = false;
};

const onConfirmCancel = () => {
  emit('cancel');
  closeCancelModal();
};

const onConfirmJump = () => {
  if (selectedStageId.value) {
    emit('jump', selectedStageId.value);
    closeJumpModal();
    selectedStageId.value = '';
  }
};
</script>
