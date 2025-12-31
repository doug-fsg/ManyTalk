<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  position: {
    type: Object,
    default: () => ({ x: 0, y: 0 }),
  },
});

const emit = defineEmits(['select', 'close']);

const emojiList = ref([
  '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
  '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
  '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
  '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
  '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧',
  '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓', '🧐',
  '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉',
  '👆', '🖕', '👇', '☝️', '👋', '🤚', '🖐️', '✋', '🖖', '👏',
  '🙌', '🤝', '🙏', '✍️', '💪', '🦾', '🦿', '🦵', '🦶', '👂',
  '🧠', '🦷', '🦴', '👀', '👁️', '👅', '👄', '💋', '🩸', '❤️',
  '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️',
  '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️', '✝️',
  '☪️', '🕉️', '☸️', '✡️', '🔯', '🕎', '☯️', '☦️', '🛐', '⛎',
];

const selectedIndex = ref(0);

const visibleEmojis = computed(() => {
  return emojiList.value.slice(0, 50); // Show first 50 emojis
});

const handleKeydown = (event) => {
  if (!props.show) return;

  switch (event.key) {
    case 'ArrowUp':
      event.preventDefault();
      selectedIndex.value = Math.max(0, selectedIndex.value - 10);
      break;
    case 'ArrowDown':
      event.preventDefault();
      selectedIndex.value = Math.min(
        visibleEmojis.value.length - 1,
        selectedIndex.value + 10
      );
      break;
    case 'ArrowLeft':
      event.preventDefault();
      selectedIndex.value = Math.max(0, selectedIndex.value - 1);
      break;
    case 'ArrowRight':
      event.preventDefault();
      selectedIndex.value = Math.min(
        visibleEmojis.value.length - 1,
        selectedIndex.value + 1
      );
      break;
    case 'Enter':
      event.preventDefault();
      selectEmoji(visibleEmojis.value[selectedIndex.value]);
      break;
    case 'Escape':
      event.preventDefault();
      emit('close');
      break;
  }
};

const selectEmoji = (emoji) => {
  emit('select', emoji);
  emit('close');
};

onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
});
</script>

<template>
  <div
    v-if="show"
    class="fixed z-50 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-600 rounded-lg shadow-lg p-2 max-w-xs"
    :style="{
      left: `${position.x}px`,
      top: `${position.y}px`,
    }"
  >
    <div class="grid grid-cols-10 gap-1 max-h-40 overflow-y-auto">
      <button
        v-for="(emoji, index) in visibleEmojis"
        :key="index"
        class="w-8 h-8 flex items-center justify-center rounded hover:bg-slate-100 dark:hover:bg-slate-700 text-lg"
        :class="{
          'bg-woot-100 dark:bg-woot-800': index === selectedIndex,
        }"
        @click="selectEmoji(emoji)"
      >
        {{ emoji }}
      </button>
    </div>
    <div class="text-xs text-slate-500 dark:text-slate-400 mt-2 px-1">
      Use arrow keys to navigate, Enter to select, Esc to close
    </div>
  </div>
</template>
