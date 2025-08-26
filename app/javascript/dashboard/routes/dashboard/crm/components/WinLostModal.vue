<template>
  <woot-modal
    :show.sync="show"
    :on-close="onClose"
  >
    <div class="win-lost-modal">
      <woot-modal-header
        :header-title="modalTitle"
        :header-content="contact.name || ''"
      />

      <form class="modal-form" @submit.prevent="onSave">
        <div class="form-content">
          <!-- Status Indicator - Compacto -->
          <div class="status-indicator">
            <div class="status-icon-wrapper" :class="statusClass">
              <fluent-icon :icon="statusIcon" size="18" />
            </div>
            <div class="status-text">
              <div class="status-label">{{ statusLabel }}</div>
            </div>
          </div>

          <!-- Campo de Observações -->
          <div class="form-group">
            <label class="form-label">
              {{ $t('KANBAN.WIN_LOST_MODAL.NOTES_LABEL') }}
            </label>
            <textarea
              v-model="notes"
              class="form-textarea"
              :placeholder="$t('KANBAN.WIN_LOST_MODAL.NOTES_PLACEHOLDER')"
              rows="2"
            />
          </div>

          <!-- Valor do Negócio -->
          <div class="deal-value-display" v-if="currentDealValue > 0">
            <div class="value-amount">
              {{ $t('KANBAN.WIN_LOST_MODAL.CURRENT_VALUE') }}: {{ formatCurrency(currentDealValue) }}
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="modal-footer">
          <woot-button
            variant="clear"
            type="button"
            @click.prevent="onClose"
          >
            {{ $t('COMMON.CANCEL') }}
          </woot-button>
          <woot-button
            :color-scheme="status === 'won' ? 'success' : 'alert'"
            variant="solid"
            type="submit"
          >
            {{ saveButtonText }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>

<script>
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';

export default {
  name: 'WinLostModal',
  components: {
    FluentIcon,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    contact: {
      type: Object,
      default: () => ({}),
    },
    status: {
      type: String, // 'won' or 'lost'
      required: true,
    },
    pipelineId: {
      type: [String, Number],
      default: null,
    },
    currentDealValue: {
      type: Number,
      default: 0,
    },
  },
  data() {
    return {
      notes: '',
    };
  },
  computed: {
    modalTitle() {
      return this.status === 'won'
        ? this.$t('KANBAN.WIN_LOST_MODAL.TITLE_WON')
        : this.$t('KANBAN.WIN_LOST_MODAL.TITLE_LOST');
    },
    statusLabel() {
      return this.status === 'won'
        ? this.$t('KANBAN.WIN_LOST_MODAL.STATUS_WON')
        : this.$t('KANBAN.WIN_LOST_MODAL.STATUS_LOST');
    },

    statusClass() {
      return {
        'status-won': this.status === 'won',
        'status-lost': this.status === 'lost',
      };
    },
    statusIcon() {
      return this.status === 'won' ? 'checkmark-circle' : 'dismiss-circle';
    },
    saveButtonText() {
      return this.status === 'won'
        ? this.$t('KANBAN.WIN_LOST_MODAL.BUTTON_WON')
        : this.$t('KANBAN.WIN_LOST_MODAL.BUTTON_LOST');
    },
  },
  methods: {
    onClose() {
      this.resetForm();
      this.$emit('close');
    },
    onSave() {
      const winLostData = {
        status: this.status,
        date: new Date().toISOString(),
        notes: this.notes.trim(),
      };

      this.$emit('save', {
        contactId: this.contact.id,
        pipelineId: this.pipelineId,
        winLostData,
        dealValue: this.currentDealValue,
      });

      this.onClose();
    },
    resetForm() {
      this.notes = '';
    },
    formatCurrency(value) {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL'
      }).format(value);
    },
  },
  watch: {
    show(newValue) {
      if (newValue) {
        this.resetForm();
      }
    },
  },
};
</script>

<style lang="scss" scoped>
.win-lost-modal {
  @apply p-4 w-full max-w-full m-auto bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100;
}

.modal-form {
  @apply mt-3;

  .form-content {
    @apply space-y-4;

    .status-indicator {
      @apply flex items-center gap-2 p-2 rounded-md bg-slate-50 dark:bg-slate-700/30 border border-slate-200 dark:border-slate-600;

      .status-icon-wrapper {
        @apply flex items-center justify-center w-6 h-6 rounded-full flex-shrink-0;

        &.status-won {
          @apply bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400;
        }

        &.status-lost {
          @apply bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400;
        }
      }

      .status-text {
        .status-label {
          @apply text-sm font-medium text-slate-900 dark:text-slate-100;
        }

        .status-desc {
          @apply text-xs text-slate-600 dark:text-slate-400;
        }
      }
    }

    .form-group {
      @apply space-y-1.5;

      .form-label {
        @apply block text-sm font-medium text-slate-700 dark:text-slate-300;
      }

      .form-textarea {
        @apply w-full px-3 py-2 text-sm border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 placeholder-slate-500 dark:placeholder-slate-400 focus:outline-none resize-none;
        min-height: 60px;

        &:focus {
          border-color: #3b82f6;
          box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
        }

        .dark-mode & {
          @apply bg-slate-700 border-slate-600 text-slate-100;
        }
      }
    }

    .deal-value-display {
      @apply p-2 bg-slate-50 dark:bg-slate-700/30 rounded-md border border-slate-200 dark:border-slate-600 text-center;

      .value-amount {
        @apply text-sm font-medium text-slate-700 dark:text-slate-300;
      }
    }
  }

  .modal-footer {
    @apply flex justify-end gap-2 pt-3 mt-4 border-t border-slate-200 dark:border-slate-600;

    .woot-button {
      @apply min-w-[80px];
    }
  }
}
</style>
