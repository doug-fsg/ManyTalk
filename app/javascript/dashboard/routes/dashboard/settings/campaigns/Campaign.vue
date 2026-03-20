#campaing.vue
<template>
  <div class="flex-1 overflow-auto">
    <campaigns-table
      :campaigns="campaigns"
      :show-empty-result="showEmptyResult"
      :is-loading="uiFlags.isFetching"
      :campaign-type="type"
      :pagination-meta="paginationMeta"
      @edit="openEditPopup"
      @delete="openDeletePopup"
      @show-history="openHistoryModal"
      @resend="handleResend"
      @page-change="onPageChange"
    />
    
    <woot-modal :show.sync="showEditPopup" :on-close="hideEditPopup">
      <component
        v-if="showEditPopup"
        :is="editComponent"
        :key="selectedCampaign.id" 
        :selected-campaign="selectedCampaign"
        @on-close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      :show.sync="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('CAMPAIGN.DELETE.CONFIRM.TITLE')"
      :message="$t('CAMPAIGN.DELETE.CONFIRM.MESSAGE')"
      :confirm-text="$t('CAMPAIGN.DELETE.CONFIRM.YES')"
      :reject-text="$t('CAMPAIGN.DELETE.CONFIRM.NO')"
    />

    <campaign-history-modal
      :show.sync="showHistoryModal"
      :campaign="selectedCampaign"
      @on-close="hideHistoryModal"
    />
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import campaignMixin from 'shared/mixins/campaignMixin';
import CampaignsTable from './CampaignsTable.vue';
import EditCampaign from './EditCampaign.vue';
import OneOffCampaign from './OneOffCampaign.vue';
import CampaignHistoryModal from './CampaignHistoryModal.vue';

export default {
  components: {
    CampaignsTable,
    EditCampaign,
    OneOffCampaign,
    CampaignHistoryModal,
  },
  mixins: [campaignMixin],
  props: {
    type: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      showEditPopup: false,
      selectedCampaign: {},
      showDeleteConfirmationPopup: false,
      showHistoryModal: false,
      editComponent: null, // Armazena o componente correto
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'campaigns/getUIFlags',
      labelList: 'labels/getLabels',
    }),
    campaigns() {
      return this.$store.getters['campaigns/getCampaigns'](this.campaignType);
    },
    paginationMeta() {
      return this.$store.getters['campaigns/getCampaignsMeta'] || {};
    },
    showEmptyResult() {
      return !this.uiFlags.isFetching && this.campaigns.length === 0;
    },
  },
  methods: {
    async handleResend(campaign) {
      try {
        this.$set(campaign, 'campaign_status', 'active');
        await this.$store.dispatch('campaigns/update', {
          id: campaign.display_id || campaign.id,
          campaign_status: 'active',
          trigger_rules: { ...(campaign.trigger_rules || {}), force_resend: true },
        });
        this.$toast.success('Campanha reenviada com sucesso!');
      } catch (error) {
        this.$toast.error('Erro ao reenviar campanha.');
        this.$set(campaign, 'campaign_status', 'completed');
      }
    },
    openEditPopup(campaign) {
      // Crie uma cópia profunda para garantir reatividade
      this.selectedCampaign = JSON.parse(JSON.stringify(campaign));

      // Definir qual componente deve ser renderizado
      this.editComponent = this.isOngoingType ? EditCampaign : OneOffCampaign;

      // Abrir o modal
      this.showEditPopup = false;
      this.$nextTick(() => {
        this.showEditPopup = true;
      });
    },
    hideEditPopup() {
      this.showEditPopup = false;
    },
    openDeletePopup(campaign) {
      this.showDeleteConfirmationPopup = true;
      this.selectedCampaign = campaign;
    },
    closeDeletePopup() {
      this.showDeleteConfirmationPopup = false;
    },
    confirmDeletion() {
      this.closeDeletePopup();
      const { id } = this.selectedCampaign;
      this.deleteCampaign(id);
    },
    async deleteCampaign(id) {
      try {
        await this.$store.dispatch('campaigns/delete', id);
        useAlert(this.$t('CAMPAIGN.DELETE.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('CAMPAIGN.DELETE.API.ERROR_MESSAGE'));
      }
    },
    openHistoryModal(campaign) {
      this.selectedCampaign = campaign;
      this.showHistoryModal = true;
    },
    hideHistoryModal() {
      this.showHistoryModal = false;
    },
    onPageChange(page) {
      this.$emit('page-change', page);
    },
  },
};
</script>

<style scoped lang="scss">
.button-wrapper {
  @apply flex justify-end pb-2.5;
}
</style>