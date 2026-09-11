<script setup>
import { computed, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { AVAILABLE_CUSTOM_ROLE_PERMISSIONS } from 'dashboard/constants/permissions';

const props = defineProps({
  selectedRole: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);
const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const name = ref(props.selectedRole?.name || '');
const description = ref(props.selectedRole?.description || '');
const permissions = ref([...(props.selectedRole?.permissions || [])]);

const uiFlags = computed(() => getters['customRoles/getUIFlags'].value);
const isEdit = computed(() => Boolean(props.selectedRole?.id));

const togglePermission = key => {
  permissions.value = permissions.value.includes(key)
    ? permissions.value.filter(item => item !== key)
    : [...permissions.value, key];
};

const submit = async () => {
  const payload = {
    name: name.value,
    description: description.value,
    permissions: permissions.value,
  };
  try {
    if (isEdit.value) {
      await store.dispatch('customRoles/update', {
        id: props.selectedRole.id,
        ...payload,
      });
    } else {
      await store.dispatch('customRoles/create', payload);
    }
    useAlert(t('CUSTOM_ROLE.FORM.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    useAlert(t('CUSTOM_ROLE.FORM.API.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        isEdit ? $t('CUSTOM_ROLE.EDIT.TITLE') : $t('CUSTOM_ROLE.ADD.TITLE')
      "
    />
    <form class="flex flex-col w-full gap-3" @submit.prevent="submit">
      <label>
        {{ $t('CUSTOM_ROLE.FORM.NAME.LABEL') }}
        <input v-model.trim="name" type="text" required />
      </label>
      <label>
        {{ $t('CUSTOM_ROLE.FORM.DESCRIPTION.LABEL') }}
        <textarea v-model.trim="description" rows="2" />
      </label>
      <fieldset class="flex flex-col gap-2">
        <legend class="font-medium text-slate-800 dark:text-slate-100">
          {{ $t('CUSTOM_ROLE.FORM.PERMISSIONS.LABEL') }}
        </legend>
        <label
          v-for="permission in AVAILABLE_CUSTOM_ROLE_PERMISSIONS"
          :key="permission"
          class="flex items-center gap-2 font-normal"
        >
          <input
            type="checkbox"
            :checked="permissions.includes(permission)"
            @change="togglePermission(permission)"
          />
          {{ $t(`CUSTOM_ROLE.PERMISSIONS.${permission.toUpperCase()}`) }}
        </label>
      </fieldset>
      <div class="flex justify-end gap-2 py-2">
        <woot-submit-button
          :disabled="!name || uiFlags.isCreating || uiFlags.isUpdating"
          :loading="uiFlags.isCreating || uiFlags.isUpdating"
          :button-text="$t('CUSTOM_ROLE.FORM.SUBMIT')"
        />
        <button class="button clear" @click.prevent="emit('close')">
          {{ $t('CUSTOM_ROLE.FORM.CANCEL') }}
        </button>
      </div>
    </form>
  </div>
</template>
