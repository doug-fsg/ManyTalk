<template>
  <div
    class="px-5 py-4 mb-2 bg-white border rounded-md dark:bg-slate-800 border-slate-50 dark:border-slate-900"
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
        <!-- Botões de histórico e reenvio à esquerda do Select -->
        <div class="flex flex-row space-x-3 mr-2">
          <woot-button
            v-if="campaign.campaign_status === 'completed'"
            variant="link"
            icon="clock"
            size="small"
            color-scheme="secondary"
            @click="$emit('show-history', campaign)"
          >
            {{ $t('CAMPAIGN.LIST.BUTTONS.HISTORY') }}
          </woot-button>
          <woot-button
            v-if="campaign.campaign_status === 'completed'"
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
            class="flex items-center justify-between h-8 px-3 text-xs font-medium rounded-md text-slate-600 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-700 focus:outline-none"
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
            class="absolute right-0 mt-1 w-36 py-1 bg-white rounded-md shadow-lg dark:bg-slate-700 z-10 border border-slate-200 dark:border-slate-600"
          >
            <button
              class="block w-full px-4 py-2 text-left text-xs hover:bg-slate-100 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-300"
              @click="handleAction('edit')"
            >
              {{ $t('CAMPAIGN.LIST.BUTTONS.EDIT') }}
            </button>
            <button 
              class="block w-full px-4 py-2 text-left text-xs hover:bg-slate-100 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-300"
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
      isDropdownOpen: false
    };
  },
  computed: {
    campaignStatus() {
      if (this.isOngoingType) {
        return this.campaign.enabled
          ? this.$t('CAMPAIGN.LIST.STATUS.ENABLED')
          : this.$t('CAMPAIGN.LIST.STATUS.DISABLED');
      }

      return this.campaign.campaign_status === 'completed'
        ? this.$t('CAMPAIGN.LIST.STATUS.COMPLETED')
        : this.$t('CAMPAIGN.LIST.STATUS.ACTIVE');
    },
    colorScheme() {
      if (this.isOngoingType) {
        return this.campaign.enabled ? 'success' : 'secondary';
      }
      return this.campaign.campaign_status === 'completed'
        ? 'secondary'
        : 'success';
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
      if (this.isOngoingType || !this.campaign.audience) return 0;
      const total = this.campaign.audience.length;
      if (total === 0) return 0;
      const successful = this.campaign.audience.filter(item => item.status === 'success').length;
      return Math.round((successful / total) * 100);
    },
    resendCampaign() {
      this.$emit('resend', this.campaign);
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
    }
  },
};
</script>