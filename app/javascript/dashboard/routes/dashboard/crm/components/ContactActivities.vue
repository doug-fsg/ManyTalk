<template>
  <div class="contact-activities">
    <!-- Header com botão de criar -->
    <div class="flex items-center justify-between mb-4">
      <h3 class="text-sm font-semibold text-slate-900 dark:text-white">
        {{ $t('ACTIVITIES.TITLE') }}
      </h3>
      <woot-button
        icon="add"
        size="small"
        variant="smooth"
        color-scheme="primary"
        @click="openCreateForm"
      >
        {{ $t('ACTIVITIES.CREATE') }}
      </woot-button>
    </div>

    <!-- Lista de atividades -->
    <div v-if="loading" class="flex items-center justify-center py-8">
      <spinner />
    </div>

    <div v-else-if="!activities.length" class="text-center py-8 text-slate-500 dark:text-slate-400 text-sm">
      <fluent-icon icon="calendar" size="32" class="mb-2 opacity-50" />
      <p>{{ $t('ACTIVITIES.EMPTY') }}</p>
    </div>

    <div v-else class="space-y-2">
      <div
        v-for="activity in activities"
        :key="activity.id"
        class="p-3 bg-white dark:bg-slate-700 rounded-lg border border-slate-200 dark:border-slate-600 transition-all duration-200 cursor-pointer hover:border-slate-300 dark:hover:border-slate-500"
        @click="openActivityDetail(activity)"
      >
        <div class="flex items-start justify-between gap-2">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <div
                :class="[
                  'flex items-center justify-center w-6 h-6 rounded flex-shrink-0',
                  activity.activity_type === 'task' ? 'bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400' : 'bg-purple-100 text-purple-600 dark:bg-purple-900/30 dark:text-purple-400'
                ]"
              >
                <fluent-icon
                  :icon="activity.activity_type === 'task' ? 'checkmark-circle' : 'send-clock'"
                  size="14"
                />
              </div>
              <span class="text-sm font-medium text-slate-900 dark:text-white truncate">
                {{ activity.title }}
              </span>
            </div>
            <div class="flex items-center gap-2 text-[11px] text-slate-500 dark:text-slate-400 ml-8">
              <span class="flex items-center gap-1">
                <fluent-icon icon="clock" size="10" />
                {{ formatDate(activity.scheduled_at) }}
              </span>
              <span
                :class="[
                  'px-1.5 py-0.5 rounded-full text-[10px] font-medium',
                  statusClasses[activity.status]
                ]"
              >
                {{ $t(`ACTIVITIES.STATUS.${activity.status.toUpperCase()}`) }}
              </span>
            </div>
            
            <!-- Preview da mensagem agendada e detalhes expandidos -->
            <div v-if="activity.description || getMessagePreview(activity)" class="ml-8 mt-2">
              <div v-if="!isActivityExpanded(activity.id)">
                <button
                  @click="toggleActivityDetails(activity.id)"
                  class="text-[11px] text-woot-500 dark:text-woot-400 hover:underline flex items-center gap-1"
                >
                  Ver mais
                  <fluent-icon icon="chevron-down" size="10" />
                </button>
              </div>
              <div v-else class="space-y-2">
                <div v-if="activity.description" class="text-[11px] text-slate-600 dark:text-slate-300">
                  {{ activity.description }}
                </div>
                <div v-if="getMessagePreview(activity)" class="text-[11px] text-slate-600 dark:text-slate-300 italic">
                  "{{ getMessagePreview(activity) }}"
                </div>
                <button
                  @click="toggleActivityDetails(activity.id)"
                  class="text-[11px] text-woot-500 dark:text-woot-400 hover:underline flex items-center gap-1"
                >
                  Ver menos
                  <fluent-icon icon="chevron-up" size="10" />
                </button>
              </div>
            </div>
          </div>
          <div class="flex items-center gap-1 flex-shrink-0" @click.stop>
            <woot-button
              v-if="activity.status === 'pending'"
              size="tiny"
              variant="clear"
              color-scheme="success"
              icon="checkmark"
              @click="handleComplete(activity.id)"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de visualização -->
    <woot-modal
      v-if="showDetail && selectedActivity"
      :show.sync="showDetail"
      :on-close="closeDetail"
    >
      <activity-detail-modal
        :activity="selectedActivity"
        :account-id="$route.params.accountId"
        @edit="openEditFromDetail"
        @delete="handleDelete"
        @complete="handleComplete"
      />
    </woot-modal>

    <!-- Modal de formulário -->
    <woot-modal
      v-if="showForm"
      :show="showForm"
      :on-close="closeForm"
    >
      <activity-form-modal
        :activity="selectedActivity"
        :contact-id="contactId"
        :pipeline-id="pipelineId"
        @submit="handleSubmit"
        @cancel="closeForm"
      />
    </woot-modal>
  </div>
</template>

<script>
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import Spinner from 'shared/components/Spinner.vue';
import { useAlert } from 'dashboard/composables';
import { formatUnixDate } from 'shared/helpers/DateHelper';
import ActivityFormModal from './ActivityFormModal.vue';
import ActivityDetailModal from '../../activities/components/ActivityDetailModal.vue';

export default {
  components: {
    FluentIcon,
    Spinner,
    ActivityFormModal,
    ActivityDetailModal,
  },
  props: {
    contactId: {
      type: Number,
      required: true,
    },
    pipelineId: {
      type: [Number, String],
      required: true,
    },
  },
  data() {
    return {
      showForm: false,
      showDetail: false,
      selectedActivity: null,
      loading: false,
      expandedActivities: {},
      statusClasses: {
        pending: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
        completed: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
        cancelled: 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300',
      },
    };
  },
  computed: {
    activities() {
      if (!this.$store.state.activities) return [];
      return this.$store.state.activities.records || [];
    },
  },
  mounted() {
    this.loadActivities();
  },
  watch: {
    contactId() {
      this.loadActivities();
    },
  },
  methods: {
    async loadActivities() {
      this.loading = true;
      try {
        await this.$store.dispatch('activities/get', {
          params: { contact_id: this.contactId },
          merge: false,
        });
      } catch (error) {
        useAlert(this.$t('ACTIVITIES.ERRORS.LOAD_FAILED'));
      } finally {
        this.loading = false;
      }
    },
    async handleComplete(activityId) {
      try {
        await this.$store.dispatch('activities/complete', { activityId });
        await this.loadActivities();
      } catch (error) {
        useAlert(this.$t('ACTIVITIES.ERRORS.COMPLETE_FAILED'));
      }
    },
    openCreateForm() {
      this.selectedActivity = null;
      this.showForm = true;
    },
    openActivityDetail(activity) {
      this.selectedActivity = activity;
      this.showDetail = true;
    },
    openEditFromDetail(activity) {
      this.selectedActivity = activity;
      this.showDetail = false;
      this.showForm = true;
    },
    closeDetail() {
      this.showDetail = false;
      this.selectedActivity = null;
    },
    async handleSubmit({ activity, inbox_id }) {
      try {
        const action = this.selectedActivity ? 'update' : 'create';
        await this.$store.dispatch(`activities/${action}`, {
          activityId: this.selectedActivity?.id,
          params: {
            ...activity,
            contact_id: this.contactId,
            contact_pipeline_position_id: this.getPipelinePositionId(),
            inbox_id,
          },
        });
        this.closeForm();
        await this.loadActivities();
      } catch (error) {
        useAlert(this.$t('ACTIVITIES.ERRORS.SAVE_FAILED'));
      }
    },
    closeForm() {
      this.showForm = false;
      this.selectedActivity = null;
    },
    async handleDelete(activityId) {
      try {
        await this.$store.dispatch('activities/destroy', { activityId });
        this.closeDetail();
        this.closeForm();
        await this.loadActivities();
        useAlert(this.$t('ACTIVITIES.SUCCESS.DELETED'));
      } catch (error) {
        useAlert(this.$t('ACTIVITIES.ERRORS.DELETE_FAILED'));
      }
    },
    formatDate(date) {
      return this.formatRelativeDate(new Date(date));
    },
    formatRelativeDate(date) {
      const now = new Date();
      const target = new Date(date);
      
      // Resetar horas para comparação de dias
      const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const targetDate = new Date(target.getFullYear(), target.getMonth(), target.getDate());
      const daysDiff = Math.floor((targetDate - nowDate) / (1000 * 60 * 60 * 24));
      
      const timeString = target.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
      
      if (daysDiff === 0) {
        return `Hoje às ${timeString}`;
      } else if (daysDiff === 1) {
        return `Amanhã às ${timeString}`;
      } else if (daysDiff === -1) {
        return `Ontem às ${timeString}`;
      } else if (daysDiff < 0) {
        const daysAgo = Math.abs(daysDiff);
        return `${daysAgo}d atrás`;
      } else if (daysDiff <= 7) {
        return `${target.toLocaleDateString('pt-BR', { weekday: 'short' })} às ${timeString}`;
      } else {
        return `${target.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' })} às ${timeString}`;
      }
    },
    getMessagePreview(activity) {
      if (activity.activity_type !== 'scheduled_message' || !activity.message_content) {
        return null;
      }
      
      // Remover tags HTML e pegar primeiros 40 caracteres
      const text = activity.message_content.replace(/<[^>]*>/g, '').trim();
      return text.length > 40 ? text.substring(0, 40) + '...' : text;
    },
    toggleActivityDetails(activityId) {
      this.$set(this.expandedActivities, activityId, !this.expandedActivities[activityId]);
    },
    isActivityExpanded(activityId) {
      return !!this.expandedActivities[activityId];
    },
    getPipelinePositionId() {
      // Buscar pipeline position do contato atual via props do modal pai
      // O modal pai já tem o contact, então podemos usar um evento ou prop
      // Por enquanto, retornar null e deixar o backend criar se necessário
      return null;
    },
  },
};
</script>

<style scoped>
.contact-activities {
  @apply h-full;
}
</style>

