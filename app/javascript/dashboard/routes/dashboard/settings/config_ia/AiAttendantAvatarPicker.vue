<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import {
  AI_ATTENDANT_AVATARS,
  avatarPreviewUrl,
} from './aiAttendantAvatars';

const emit = defineEmits(['input', 'update:modelValue', 'update:model-value']);

const props = defineProps({
  value: {
    type: String,
    default: undefined,
  },
  modelValue: {
    type: String,
    default: undefined,
  },
});

const open = ref(false);
const rootRef = ref(null);
const triggerRef = ref(null);
const panelStyle = ref({});

const selectedId = computed(() => {
  if (props.value !== undefined && props.value !== null) return props.value;
  if (props.modelValue !== undefined && props.modelValue !== null) {
    return props.modelValue;
  }
  return '';
});

const selectedSrc = computed(() => avatarPreviewUrl(selectedId.value));

const preloadPreviewImages = () => {
  AI_ATTENDANT_AVATARS.forEach(({ id }) => {
    const img = new Image();
    img.decoding = 'async';
    img.src = avatarPreviewUrl(id);
  });
};

const PANEL_PADDING = 16;
const PANEL_GAP = 14;
const GRID_COLS = 2;
/** Source files are 1024×1024; preview size for choosing an avatar. */
const TARGET_CHOICE_PX = 152;
const MIN_CHOICE_PX = 120;

const measureChoiceSize = () => {
  const viewportPadding = 12;
  const maxPanelWidth = window.innerWidth - viewportPadding * 2;
  const fromViewport = Math.floor(
    (maxPanelWidth - PANEL_PADDING * 2 - PANEL_GAP * (GRID_COLS - 1)) /
      GRID_COLS
  );
  return Math.min(TARGET_CHOICE_PX, Math.max(MIN_CHOICE_PX, fromViewport));
};

const panelWidthForChoice = choicePx =>
  PANEL_PADDING * 2 + GRID_COLS * choicePx + PANEL_GAP * (GRID_COLS - 1);

const updatePanelPosition = () => {
  const trigger = triggerRef.value;
  if (!trigger) return;

  const rect = trigger.getBoundingClientRect();
  const choicePx = measureChoiceSize();
  const panelWidth = panelWidthForChoice(choicePx);
  const viewportPadding = 12;
  let left = rect.left;

  if (left + panelWidth > window.innerWidth - viewportPadding) {
    left = window.innerWidth - panelWidth - viewportPadding;
  }
  if (left < viewportPadding) left = viewportPadding;

  panelStyle.value = {
    top: `${rect.bottom + 8}px`,
    left: `${left}px`,
    width: `${panelWidth}px`,
    '--ia-avatar-choice-size': `${choicePx}px`,
  };
};

const close = () => {
  open.value = false;
};

const openPanel = async () => {
  open.value = true;
  await nextTick();
  updatePanelPosition();
};

const toggle = () => {
  if (open.value) {
    close();
    return;
  }
  preloadPreviewImages();
  openPanel();
};

const emitValue = id => {
  emit('input', id);
  emit('update:modelValue', id);
  emit('update:model-value', id);
};

const choose = id => {
  emitValue(id);
  close();
};

const onClickAway = () => {
  if (open.value) close();
};

const onViewportChange = () => {
  if (open.value) updatePanelPosition();
};

watch(open, isOpen => {
  if (isOpen) onViewportChange();
});

onMounted(() => {
  preloadPreviewImages();
  window.addEventListener('resize', onViewportChange);
  window.addEventListener('scroll', onViewportChange, true);
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', onViewportChange);
  window.removeEventListener('scroll', onViewportChange, true);
});
</script>

<template>
  <div
    ref="rootRef"
    v-on-clickaway="onClickAway"
    class="ia-avatar-picker"
    @keyup.esc="close"
  >
    <button
      ref="triggerRef"
      type="button"
      class="ia-avatar-picker__trigger"
      :aria-expanded="open ? 'true' : 'false'"
      :aria-haspopup="true"
      :aria-label="$t('AI_ATTENDANT.FORM.AVATAR.OPEN')"
      @click.stop="toggle"
    >
      <img
        :src="selectedSrc"
        alt=""
        class="ia-avatar-picker__photo"
      />
      <span class="ia-avatar-picker__overlay" aria-hidden="true">
        <fluent-icon icon="edit" size="14" class="text-white" />
      </span>
    </button>

    <div
      v-if="open"
      class="ia-avatar-picker__panel"
      role="listbox"
      :style="panelStyle"
      :aria-label="$t('AI_ATTENDANT.FORM.AVATAR.OPEN')"
      @click.stop
    >
      <button
        v-for="item in AI_ATTENDANT_AVATARS"
        :key="item.id"
        type="button"
        role="option"
        class="ia-avatar-picker__choice"
        :class="{
          'ia-avatar-picker__choice--selected': item.id === selectedId,
        }"
        :aria-selected="item.id === selectedId ? 'true' : 'false'"
        :aria-label="$t(`AI_ATTENDANT.FORM.AVATAR.OPTIONS.${item.id}`)"
        @click="choose(item.id)"
      >
        <img
          :src="avatarPreviewUrl(item.id)"
          alt=""
          class="ia-avatar-picker__choice-img"
          width="256"
          height="256"
          loading="lazy"
          decoding="async"
        />
      </button>
    </div>
  </div>
</template>

<style scoped lang="scss">
.ia-avatar-picker {
  position: relative;
  display: inline-flex;
}

.ia-avatar-picker__trigger {
  position: relative;
  margin: 0;
  padding: 0;
  border: none;
  background: transparent;
  border-radius: 9999px;
  cursor: pointer;
  line-height: 0;

  &:focus-visible {
    outline: none;
    box-shadow: 0 0 0 2px #fff, 0 0 0 4px var(--w-500, #1f93ff);
  }
}

.ia-avatar-picker__photo {
  width: 40px;
  height: 40px;
  border-radius: 9999px;
  object-fit: cover;
  display: block;
  border: 1px solid rgb(226 232 240);
  background: #fff;
}

.dark .ia-avatar-picker__photo {
  border-color: rgb(71 85 105);
}

.ia-avatar-picker__overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 9999px;
  background: rgb(15 23 42 / 0.35);
  opacity: 0;
  transition: opacity 0.15s ease;
  pointer-events: none;
}

@media (hover: hover) and (pointer: fine) {
  .ia-avatar-picker__trigger:hover .ia-avatar-picker__overlay {
    opacity: 1;
  }
}

.ia-avatar-picker__panel {
  position: fixed;
  z-index: 9999;
  box-sizing: border-box;
  display: grid;
  grid-template-columns: repeat(2, var(--ia-avatar-choice-size, 152px));
  justify-content: center;
  gap: 14px;
  padding: 16px;
  border-radius: 12px;
  border: 1px solid rgb(226 232 240);
  background: #fff;
  box-shadow: 0 8px 24px rgb(15 23 42 / 0.12);
}

.dark .ia-avatar-picker__panel {
  border-color: rgb(51 65 85);
  background: rgb(15 23 42);
  box-shadow: 0 4px 16px rgb(0 0 0 / 0.35);
}

.ia-avatar-picker__choice {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
  width: var(--ia-avatar-choice-size, 152px);
  height: var(--ia-avatar-choice-size, 152px);
  border: 3px solid transparent;
  border-radius: 9999px;
  background: transparent;
  cursor: pointer;
  line-height: 0;
  overflow: hidden;
  transition: border-color 0.12s ease;

  &:hover {
    border-color: rgb(203 213 225);
  }

  &:focus-visible {
    outline: none;
    border-color: var(--w-500, #1f93ff);
  }
}

.dark .ia-avatar-picker__choice:hover {
  border-color: rgb(100 116 139);
}

.ia-avatar-picker__choice--selected {
  border-color: var(--w-500, #1f93ff);
}

.ia-avatar-picker__choice-img {
  width: 100%;
  height: 100%;
  border-radius: 9999px;
  object-fit: cover;
  display: block;
  background: rgb(248 250 252);
}

.dark .ia-avatar-picker__choice-img {
  background: rgb(30 41 59);
}
</style>
