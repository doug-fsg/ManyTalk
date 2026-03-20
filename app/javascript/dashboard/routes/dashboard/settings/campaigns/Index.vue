<template>
  <div class="flex-1 overflow-auto p-4">
    <woot-button
      color-scheme="success"
      class-names="button--fixed-top"
      icon="add-circle"
      @click="openAddPopup"
    >
      {{ buttonText }}
    </woot-button>

    <!-- Filtros apenas para campanhas one_off (WhatsApp) -->
    <div v-if="isOneOffType" class="flex items-center gap-2 mb-4 flex-wrap">
      <div class="flex items-center gap-1">
        <button
          v-for="filter in statusFilters"
          :key="filter.value"
          class="px-3 py-1 text-xs font-medium rounded-lg transition-colors duration-150"
          :class="activeStatusFilter === filter.value
            ? 'bg-woot-500 text-white'
            : 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600'"
          @click="onStatusFilter(filter.value)"
        >
          {{ filter.label }}
        </button>
      </div>
      <!-- Busca ao estilo Kanban: ícone que expande o campo -->
      <div class="flex items-center gap-2">
        <button
          @click="showSearch = !showSearch"
          :class="[
            'relative inline-flex items-center justify-center w-8 h-8 rounded-lg text-xs font-medium transition-all duration-200 ease-smooth',
            'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100',
            'hover:bg-slate-50 dark:hover:bg-slate-700',
            showSearch ? 'bg-woot-50 text-woot-600 dark:bg-woot-900/20 dark:text-woot-400' : ''
          ]"
          v-tooltip.top="showSearch ? '' : $t('CAMPAIGN.FILTERS.SEARCH_PLACEHOLDER')"
        >
          <fluent-icon icon="search" size="14" />
        </button>
        <transition
          enter-active-class="transition ease-out duration-200"
          enter-from-class="opacity-0 -translate-x-2"
          enter-to-class="opacity-100 translate-x-0"
          leave-active-class="transition ease-in duration-150"
          leave-from-class="opacity-100 translate-x-0"
          leave-to-class="opacity-0 -translate-x-2"
        >
          <input
            v-show="showSearch"
            v-model="searchQuery"
            type="search"
            :placeholder="$t('CAMPAIGN.FILTERS.SEARCH_PLACEHOLDER')"
            class="px-3 py-1.5 text-xs border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 dark:placeholder-slate-400 w-48 transition-colors duration-150 ease-smooth"
            @input="onSearchInput"
          />
        </transition>
      </div>
    </div>

    <campaign @page-change="fetchCampaigns" />
    <woot-modal :show.sync="showAddPopup" :on-close="hideAddPopup">
      <add-campaign @on-close="hideAddPopup" />
    </woot-modal>
    
    <!-- Modal para Campanhas Únicas -->
    <woot-modal v-if="isOneOffType" :show.sync="showOneOffPopup" :on-close="hideOneOffPopup">
      <div class="p-4 flex flex-col justify-center items-center text-center">

        <h3>{{ $t('CAMPAIGN.MODAL.TITLE') }}</h3>
        <p>{{ $t('CAMPAIGN.MODAL.DESCRIPTION') }}</p>
        <div class="flex justify-center gap-4 mt-4">
  <woot-button
    class="hover-woot"
    color-scheme="secondary"
    @click="handleSingleBlast"
  >
  {{ $t('CAMPAIGN.MODAL.BUTTON_SINGLE') }}
  </woot-button>
  <woot-button
    class="hover-woot"
    color-scheme="secondary"
    @click="handleFlowBlast"
  >
  {{ $t('CAMPAIGN.MODAL.BUTTON_FLOW') }}
  </woot-button>
</div>
      </div>
    </woot-modal>
    
    <!-- Componentes dinamicamente carregados -->
    <woot-modal :show.sync="showComponentModal" :on-close="hideComponentModal">
      <component :is="currentComponent" @on-close="hideComponentModal" />
    </woot-modal>
  </div>
</template>

<script>
import campaignMixin from 'shared/mixins/campaignMixin';
import Campaign from './Campaign.vue';
import AddCampaign from './AddCampaign.vue';
import OneOffCampaign from './OneOffCampaign.vue'; // Importando o OneOffCampaign

export default {
  components: {
    Campaign,
    AddCampaign,
    OneOffCampaign,
  },
  mixins: [campaignMixin],
  data() {
    return {
      showAddPopup: false,
      showOneOffPopup: false,
      showComponentModal: false,
      currentComponent: null,
      searchQuery: '',
      showSearch: false,
      activeStatusFilter: '',
      searchDebounce: null,
    };
  },
  computed: {
    buttonText() {
      if (this.isOngoingType) {
        return this.$t('CAMPAIGN.ONGOING.HEADER');
      }
      return this.$t('CAMPAIGN.ADD.CREATE_BUTTON_TEXT');
    },
    isOneOffType() {
      return !this.isOngoingType;
    },
    statusFilters() {
      return [
        { value: '', label: this.$t('CAMPAIGN.FILTERS.ALL') },
        { value: 'active', label: this.$t('CAMPAIGN.LIST.STATUS.ACTIVE') },
        { value: 'processing', label: this.$t('CAMPAIGN.LIST.STATUS.PROCESSING') },
        { value: 'completed', label: this.$t('CAMPAIGN.LIST.STATUS.COMPLETED') },
        { value: 'paused', label: this.$t('CAMPAIGN.LIST.STATUS.PAUSED') },
        { value: 'stopped', label: this.$t('CAMPAIGN.LIST.STATUS.STOPPED') },
      ];
    },
  },
  mounted() {
    this.fetchCampaigns();
  },
  watch: {
    campaignType: {
      handler(newVal) {
        if (newVal !== 'one_off') {
          this.searchQuery = '';
          this.showSearch = false;
          this.activeStatusFilter = '';
        }
        this.fetchCampaigns();
      },
    },
  },
  methods: {
    openAddPopup() {
      if (this.isOneOffType) {
        this.openOneOffPopup(); // Abre o modal de campanhas únicas
      } else {
        this.showAddPopup = true; // Abre o modal padrão de campanhas
      }
    },
    hideAddPopup() {
      this.showAddPopup = false;
    },
    openOneOffPopup() {
      this.showOneOffPopup = true; // Modal para campanhas únicas
    },
    hideOneOffPopup() {
      this.showOneOffPopup = false;
    },
    handleSingleBlast() {
      // Abre o OneOffCampaign.vue
      this.currentComponent = 'OneOffCampaign';
      this.showComponentModal = true;
      this.hideOneOffPopup();
    },
    handleFlowBlast() {
      // Abre o AddCampaign.vue
      this.currentComponent = 'AddCampaign';
      this.showComponentModal = true;
      this.hideOneOffPopup();
    },
    hideComponentModal() {
      this.showComponentModal = false;
      this.currentComponent = null;
    },
    onSearchInput() {
      clearTimeout(this.searchDebounce);
      this.searchDebounce = setTimeout(() => {
        this.fetchCampaigns();
      }, 400);
    },
    onStatusFilter(status) {
      this.activeStatusFilter = status;
      this.fetchCampaigns();
    },
    fetchCampaigns(page = 1) {
      const params = {
        page,
        campaign_type: this.campaignType,
        per_page: 15,
      };
      if (this.isOneOffType) {
        if (this.activeStatusFilter) params.campaign_status = this.activeStatusFilter;
        if (this.searchQuery.trim()) params.search = this.searchQuery.trim();
      }
      this.$store.dispatch('campaigns/get', params);
    },
  },
};
</script>
<style scoped>
.hover-woot:hover {
  background-color: var(--color-woot);
  color: white;
}
</style>
