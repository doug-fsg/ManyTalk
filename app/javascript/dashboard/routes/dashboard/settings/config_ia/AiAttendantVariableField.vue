<script setup>
import { computed, inject, nextTick, ref } from 'vue';
import MentionBox from 'dashboard/components/widgets/mentions/MentionBox.vue';
import {
  FILE_VARIABLES_KEY,
  VARIABLE_INSERT_KEY,
} from './aiAttendantVariables';
import { applyVariableToken, openVariableQuery } from './aiAttendantVariableQuery';
import { tokenStatus } from './aiAttendantReferenceVariables';

const props = defineProps({
  value: {
    type: String,
    default: '',
  },
  placeholder: {
    type: String,
    default: '',
  },
  rows: {
    type: [Number, String],
    default: 3,
  },
  inputClass: {
    type: String,
    default: '',
  },
  id: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['input']);

const fileVariables = inject(FILE_VARIABLES_KEY, ref([]));
const insertTarget = inject(VARIABLE_INSERT_KEY, ref(null));
const inputRef = ref(null);
const showMenu = ref(false);
const searchTerm = ref('');

const items = computed(() => {
  const query = String(searchTerm.value || '').toLowerCase();
  return (fileVariables.value || []).filter(item => {
    if (!query) return true;
    return (
      item.label.toLowerCase().includes(query) ||
      item.description.toLowerCase().includes(query)
    );
  });
});

const shouldShowMenu = computed(
  () => showMenu.value && items.value.length > 0
);

const tokenHints = computed(() =>
  tokenStatus(props.value, fileVariables.value)
);

const currentCursor = () => {
  const el = inputRef.value;
  if (!el || el.selectionStart == null) return (props.value || '').length;
  return el.selectionStart;
};

const syncMenu = () => {
  const query = openVariableQuery(props.value, currentCursor());
  if (!query) {
    showMenu.value = false;
    searchTerm.value = '';
    return;
  }
  showMenu.value = true;
  searchTerm.value = query.search;
};

const writeValue = (next, cursor) => {
  emit('input', next);
  nextTick(() => {
    const el = inputRef.value;
    if (!el || cursor == null) return;
    el.focus();
    el.setSelectionRange(cursor, cursor);
  });
};

const insertToken = token => {
  const applied = applyVariableToken(props.value, token, currentCursor());
  writeValue(applied.value, applied.cursor);
  showMenu.value = false;
  searchTerm.value = '';
};

const onFocus = () => {
  insertTarget.value = insertToken;
  syncMenu();
};

const onInput = event => {
  emit('input', event.target.value);
  nextTick(syncMenu);
};

const onKeydown = event => {
  if (event.key === 'Escape' && showMenu.value) {
    showMenu.value = false;
    event.stopPropagation();
  }
};

const onSelect = item => {
  if (!item?.key) return;
  insertToken(`{{${item.key}}}`);
};
</script>

<template>
  <div :id="id || undefined" class="relative w-full scroll-mt-28">
    <mention-box
      v-if="shouldShowMenu"
      type="variable"
      :items="items"
      @mention-select="onSelect"
    />
    <textarea
      ref="inputRef"
      :value="value"
      :rows="rows"
      :placeholder="placeholder"
      :class="inputClass"
      @input="onInput"
      @focus="onFocus"
      @click="syncMenu"
      @keyup="syncMenu"
      @keydown="onKeydown"
    />
    <ul
      v-if="tokenHints.length"
      class="flex flex-col gap-1 m-0 mt-1 p-0 list-none"
    >
      <li
        v-for="(hint, index) in tokenHints"
        :key="`${hint.token}-${index}`"
        class="text-xs leading-4"
        :class="
          hint.linked
            ? 'text-green-700 dark:text-green-400'
            : 'text-red-600 dark:text-red-400'
        "
      >
        {{
          hint.linked
            ? $t('AI_ATTENDANT.FORM.FILES.TOKEN_LINKED', {
                name: hint.filename || hint.key,
              })
            : $t('AI_ATTENDANT.FORM.FILES.TOKEN_MISSING', {
                name: hint.key || hint.token,
              })
        }}
      </li>
    </ul>
  </div>
</template>
