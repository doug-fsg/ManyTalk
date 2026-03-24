<template>
  <div
    class="px-5 py-4 mb-2 bg-white border rounded-xl dark:bg-slate-800 border-slate-100 dark:border-slate-700 shadow-soft hover:shadow-soft-lg transition-all duration-300 ease-smooth dark:hover:border-slate-600"
  >
    <div class="flex flex-row items-start justify-between">
      <div class="flex flex-col">
        <div
          class="mb-1 -mt-1 text-base font-medium text-slate-900 dark:text-slate-100"
        >
          {{ campaign.title }}
        </div>
        <div
          v-dompurify-html="formatMessage(campaign.message)"
          class="text-sm line-clamp-1 [&>p]:mb-0"
        />
      </div>
      
      <!-- Reorganização da área de botões -->
      <div class="flex flex-row items-center">
        <!-- Botões de histórico, controle e reenvio à esquerda do Select -->
        <div class="flex flex-row space-x-3 mr-2">
          <!-- Indicador de progresso durante disparo -->
          <div
            v-if="isProcessing"
            class="flex items-center space-x-2 text-xs text-woot-600 dark:text-woot-400"
          >
            <span class="animate-spin inline-block w-3 h-3 border-2 border-current border-t-transparent rounded-full"></span>
            <span>{{ progressText }}</span>
          </div>
          <!-- Botão Cancelar quando está agendado -->
          <woot-button
            v-if="isActiveScheduled && !isOngoingType"
            :is-loading="isStopping"
            variant="link"
            icon="dismiss-circle"
            size="small"
            color-scheme="alert"
            @click="stopCampaign"
          >
            Cancelar
          </woot-button>
          <!-- Botões Pause/Stop quando em disparo -->
          <woot-button
            v-if="isProcessing && !isOngoingType"
            :is-loading="isPausing"
            variant="link"
            icon="pause"
            size="small"
            color-scheme="secondary"
            @click="pauseCampaign"
          >
            {{ $t('CAMPAIGN.LIST.BUTTONS.PAUSE') }}
          </woot-button>
          <woot-button
            v-if="isProcessing && !isOngoingType"
            :is-loading="isStopping"
            variant="link"
            icon="stop"
            size="small"
            color-scheme="alert"
            @click="stopCampaign"
          >
            {{ $t('CAMPAIGN.LIST.BUTTONS.STOP') }}
          </woot-button>
          <!-- Botão Resume quando pausada -->
          <woot-button
            v-if="isPaused && !isOngoingType"
            :is-loading="isResuming"
            variant="link"
            icon="play"
            size="small"
            color-scheme="success"
            @click="resumeCampaign"
          >
            {{ $t('CAMPAIGN.LIST.BUTTONS.RESUME') }}
          </woot-button>
          <woot-button
            v-if="canShowHistory"
            variant="link"
            icon="clock"
            size="small"
            color-scheme="secondary"
            @click="$emit('show-history', campaign)"
          >
            {{ $t('CAMPAIGN.LIST.BUTTONS.HISTORY') }}
          </woot-button>
          <woot-button
            v-if="canShowResend"
            variant="link"
            icon="refresh"
            size="small"
            color-scheme="secondary"
            @click="resendCampaign"
          >
            {{ $t('CAMPAIGN.LIST.BUTTONS.RESEND') }}
          </woot-button>
        </div>
        
        <!-- Select sempre na direita com ícone de seta -->
        <div class="relative">
          <button 
            class="flex items-center justify-between h-8 px-3 text-xs font-medium rounded-lg text-slate-600 hover:bg-slate-50 dark:text-slate-400 dark:hover:bg-slate-700 focus:outline-none focus:ring-2 focus:ring-woot-500 focus:ring-offset-1 transition-all duration-200 ease-smooth"
            @click="toggleDropdown"
          >
          <span class="mr-1"> {{ $t('MACROS.ADD.FORM.ACTIONS.LABEL') }} </span>
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
            </svg>
          </button>
          <!-- Dropdown menu -->
          <div
            v-if="isDropdownOpen"
            class="absolute right-0 mt-1 w-36 py-1 bg-white rounded-lg shadow-soft-xl dark:bg-slate-700 z-10 border border-slate-200 dark:border-slate-600 animate-scale-in"
          >
            <button
              class="block w-full px-4 py-2 text-left text-xs hover:bg-slate-50 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-300 transition-colors duration-150 ease-smooth first:rounded-t-lg last:rounded-b-lg"
              @click="handleAction('edit')"
            >
              {{ $t('CAMPAIGN.LIST.BUTTONS.EDIT') }}
            </button>
            <button 
              class="block w-full px-4 py-2 text-left text-xs hover:bg-slate-50 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-300 transition-colors duration-150 ease-smooth first:rounded-t-lg last:rounded-b-lg"
              @click="handleAction('delete')"
            >
              {{ $t('CAMPAIGN.LIST.BUTTONS.DELETE') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="flex flex-row items-center mt-5 space-x-3">
      <woot-label
        small
        :title="campaignStatus"
        :color-scheme="colorScheme"
        class="mr-3 text-xs"
      />
      <inbox-name :inbox="campaign.inbox" class="mb-1 ltr:ml-0 rtl:mr-0" />
      <user-avatar-with-name
        v-if="campaign.sender"
        :user="campaign.sender"
        class="mb-1"
      />
      <div
        v-if="campaign.trigger_rules.url"
        class="w-1/4 mb-1 text-xs text-woot-600 text-truncate"
      >
        {{ campaign.trigger_rules.url }}
      </div>
      <div
        v-if="campaign.scheduled_at"
        class="mb-1 text-xs text-slate-700 dark:text-slate-500"
      >
        {{ messageStamp(new Date(campaign.scheduled_at), 'dd/MM, h:mm a') }}
      </div>
      <div
        v-if="!isOngoingType"
        class="mb-1 text-xs text-slate-700 dark:text-slate-500"
      >
        {{ $t('CAMPAIGN.LIST.DELIVERY_RATE', { rate: successPercentage() }) }}
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import UserAvatarWithName from 'dashboard/components/widgets/UserAvatarWithName.vue';
import InboxName from 'dashboard/components/widgets/InboxName.vue';
import messageFormatterMixin from 'shared/mixins/messageFormatterMixin';
import { messageStamp } from 'shared/helpers/timeHelper';

export default {
  components: {
    UserAvatarWithName,
    InboxName,
  },
  mixins: [messageFormatterMixin],
  props: {
    campaign: {
      type: Object,
      required: true,
    },
    isOngoingType: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return {
      isDropdownOpen: false,
      isPausing: false,
      isStopping: false,
      isResuming: false,
    };
  },
  computed: {
    ...mapGetters({
      getCampaignProgress: 'campaigns/getCampaignProgress',
    }),
    liveProgress() {
      return this.getCampaignProgress(this.campaign.id);
    },
    isProcessing() {
      const status = this.liveProgress?.status || this.campaign.campaign_status;
      return status === 'processing';
    },
    isActiveScheduled() {
      const status = this.liveProgress?.status || this.campaign.campaign_status;
      return status === 'active';
    },
    isPaused() {
      const status = this.liveProgress?.status || this.campaign.campaign_status;
      return status === 'paused';
    },
    canShowHistory() {
      if (this.isOngoingType) return false;
      const status = this.liveProgress?.status || this.campaign.campaign_status;
      return ['completed', 'stopped', 'processing', 'paused'].includes(status);
    },
    canShowResend() {
      if (this.isOngoingType) return false;
      const status = this.liveProgress?.status || this.campaign.campaign_status;
      return status === 'completed' || status === 'stopped';
    },
    progressText() {
      if (!this.liveProgress) return this.$t('CAMPAIGN.LIST.STATUS.PROCESSING');
      const { sent = 0, failed = 0, total = 0 } = this.liveProgress;
      if (total === 0) return this.$t('CAMPAIGN.LIST.STATUS.PROCESSING');
      return `${sent + failed}/${total}`;
    },
    campaignStatus() {
      if (this.isOngoingType) {
        return this.campaign.enabled
          ? this.$t('CAMPAIGN.LIST.STATUS.ENABLED')
          : this.$t('CAMPAIGN.LIST.STATUS.DISABLED');
      }

      const status = this.liveProgress?.status || this.campaign.campaign_status;
      if (status === 'completed') return this.$t('CAMPAIGN.LIST.STATUS.COMPLETED');
      if (status === 'processing') return this.$t('CAMPAIGN.LIST.STATUS.PROCESSING');
      if (status === 'paused') return this.$t('CAMPAIGN.LIST.STATUS.PAUSED');
      if (status === 'stopped') return this.$t('CAMPAIGN.LIST.STATUS.STOPPED');
      return this.$t('CAMPAIGN.LIST.STATUS.ACTIVE');
    },
    colorScheme() {
      if (this.isOngoingType) {
        return this.campaign.enabled ? 'success' : 'secondary';
      }
      const status = this.liveProgress?.status || this.campaign.campaign_status;
      if (status === 'completed') return 'secondary';
      if (status === 'processing') return 'warning';
      if (status === 'paused') return 'warning';
      if (status === 'stopped') return 'alert';
      return 'success';
    },
  },
  mounted() {
    document.addEventListener('click', this.closeDropdownOnClickOutside);
  },
  beforeDestroy() {
    document.removeEventListener('click', this.closeDropdownOnClickOutside);
  },
  methods: {
    messageStamp,
    successPercentage() {
      if (this.isOngoingType) return 0;
      const progress = this.liveProgress || {};
      const stats = this.campaign.trigger_rules?.delivery_stats || {};
      const sent = progress.sent ?? stats.sent ?? 0;
      const total = progress.total ?? stats.total ?? this.campaign.audience?.length ?? 0;
      if (total === 0) return 0;
      return Math.round((sent / total) * 100);
    },
    resendCampaign() {
      this.$emit('resend', this.campaign);
    },
    async pauseCampaign() {
      if (this.isPausing) return;
      this.isPausing = true;
      try {
        await this.$store.dispatch('campaigns/pause', this.campaign.id);
        this.$emit('pause', this.campaign);
        this.$toast.success(this.$t('CAMPAIGN.LIST.PAUSE_SUCCESS'));
      } catch (error) {
        this.$toast.error(this.formatApiError(error) || this.$t('CAMPAIGN.LIST.PAUSE_ERROR'));
      } finally {
        this.isPausing = false;
      }
    },
    async stopCampaign() {
      if (this.isStopping) return;
      this.isStopping = true;
      try {
        await this.$store.dispatch('campaigns/stop', this.campaign.id);
        this.$emit('stop', this.campaign);
        this.$toast.success(this.$t('CAMPAIGN.LIST.STOP_SUCCESS'));
      } catch (error) {
        this.$toast.error(this.formatApiError(error) || this.$t('CAMPAIGN.LIST.STOP_ERROR'));
      } finally {
        this.isStopping = false;
      }
    },
    async resumeCampaign() {
      if (this.isResuming) return;
      this.isResuming = true;
      try {
        await this.$store.dispatch('campaigns/resume', this.campaign.id);
        this.$emit('resume', this.campaign);
        this.$toast.success(this.$t('CAMPAIGN.LIST.RESUME_SUCCESS'));
      } catch (error) {
        this.$toast.error(this.formatApiError(error) || this.$t('CAMPAIGN.LIST.RESUME_ERROR'));
      } finally {
        this.isResuming = false;
      }
    },
    toggleDropdown(event) {
      event.stopPropagation();
      this.isDropdownOpen = !this.isDropdownOpen;
    },
    handleAction(action) { 
      if (action === 'edit') {
        this.$emit('edit', this.campaign);
      } else if (action === 'delete') {
        this.$emit('delete', this.campaign);
      }
      this.isDropdownOpen = false;
    },
    closeDropdownOnClickOutside(event) {
      if (this.$el && !this.$el.contains(event.target)) {
        this.isDropdownOpen = false;
      }
    },
    formatApiError(error) {
      const errors = error?.response?.data?.errors;
      if (!errors) return null;
      return Array.isArray(errors) ? errors.join(', ') : errors;
    },
  },
};
</script>