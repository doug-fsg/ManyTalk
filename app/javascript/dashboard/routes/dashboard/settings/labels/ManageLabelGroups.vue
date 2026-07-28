<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

export default {
  computed: {
    ...mapGetters({
      groups: 'labelGroups/getLabelGroups',
      uiFlags: 'labelGroups/getUIFlags',
    }),
  },
  data() {
    return {
      name: '',
      editingGroupId: null,
      editingName: '',
    };
  },
  mounted() {
    this.$store.dispatch('labelGroups/get');
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    async addGroup() {
      const name = this.name.trim();
      if (!name) {
        return;
      }

      try {
        await this.$store.dispatch('labelGroups/create', { name });
        this.name = '';
        useAlert(this.$t('LABEL_MGMT.GROUP.API.CREATE_SUCCESS'));
      } catch (error) {
        useAlert(
          error?.message || this.$t('LABEL_MGMT.GROUP.API.CREATE_ERROR')
        );
      }
    },
    startEdit(group) {
      this.editingGroupId = group.id;
      this.editingName = group.name;
      this.$nextTick(() => {
        const input = this.$refs[`edit-input-${group.id}`];
        const el = Array.isArray(input) ? input[0] : input;
        if (el) {
          el.focus();
          el.select();
        }
      });
    },
    cancelEdit() {
      this.editingGroupId = null;
      this.editingName = '';
    },
    async saveEdit(group) {
      if (this.editingGroupId !== group.id) {
        return;
      }

      const name = this.editingName.trim();
      if (!name || name === group.name) {
        this.cancelEdit();
        return;
      }

      const groupId = group.id;
      this.cancelEdit();

      try {
        await this.$store.dispatch('labelGroups/update', {
          id: groupId,
          name,
        });
        this.$store.dispatch('labels/get');
        useAlert(this.$t('LABEL_MGMT.GROUP.API.UPDATE_SUCCESS'));
      } catch (error) {
        useAlert(
          error?.message || this.$t('LABEL_MGMT.GROUP.API.UPDATE_ERROR')
        );
      }
    },
    onDelete(group) {
      this.$emit('delete', group);
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('LABEL_MGMT.GROUP.MANAGE')"
      :header-content="$t('LABEL_MGMT.GROUP.HELP_SIDEBAR')"
    />
    <form class="flex flex-wrap mx-0 w-full" @submit.prevent="addGroup">
      <woot-input
        v-model.trim="name"
        class="w-full"
        :label="$t('LABEL_MGMT.GROUP.LABEL')"
        :placeholder="$t('LABEL_MGMT.GROUP.PLACEHOLDER')"
      />

      <div class="w-full mb-4">
        <table
          v-if="groups.length"
          class="w-full min-w-full divide-y divide-slate-75 dark:divide-slate-700"
        >
          <tbody
            class="divide-y divide-slate-25 dark:divide-slate-800 text-slate-700 dark:text-slate-100"
          >
            <tr v-for="group in groups" :key="group.id">
              <td class="py-4">
                <input
                  v-if="editingGroupId === group.id"
                  :ref="`edit-input-${group.id}`"
                  v-model.trim="editingName"
                  type="text"
                  class="mb-0"
                  :disabled="uiFlags.isUpdating"
                  @click.stop
                  @keydown.enter.prevent="saveEdit(group)"
                  @keydown.esc.prevent="cancelEdit"
                  @blur="saveEdit(group)"
                />
                <button
                  v-else
                  type="button"
                  class="font-medium break-words text-left text-slate-700 dark:text-slate-100 hover:text-woot-500 dark:hover:text-woot-400 cursor-pointer bg-transparent border-0 p-0"
                  @click="startEdit(group)"
                >
                  {{ group.name }}
                </button>
              </td>
              <td class="py-4 w-10">
                <div class="flex justify-end">
                  <woot-button
                    v-tooltip.top="$t('LABEL_MGMT.FORM.DELETE')"
                    variant="smooth"
                    color-scheme="alert"
                    size="tiny"
                    icon="dismiss-circle"
                    class-names="grey-btn"
                    type="button"
                    @click="onDelete(group)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <p
          v-else
          class="text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('LABEL_MGMT.GROUP.EMPTY') }}
        </p>
      </div>

      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <woot-button
          :is-disabled="!name || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
        >
          {{ $t('LABEL_MGMT.GROUP.ADD') }}
        </woot-button>
        <woot-button class="button clear" @click.prevent="onClose">
          {{ $t('LABEL_MGMT.FORM.CANCEL') }}
        </woot-button>
      </div>
    </form>
  </div>
</template>
