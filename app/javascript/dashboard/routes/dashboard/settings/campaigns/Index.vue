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
    <campaign />
    <woot-modal :show.sync="showAddPopup" :on-close="hideAddPopup">
      <add-campaign @on-close="hideAddPopup" />
    </woot-modal>
    
    <!-- Modal para Campanhas Únicas -->
    <woot-modal v-if="isOneOffType" :show.sync="showOneOffPopup" :on-close="hideOneOffPopup">
      <div class="p-4 flex flex-col justify-center items-center text-center">

        <h3>Escolha o tipo de envio</h3> <!-- CAMPAIGN.MODAL.TITLE -->
        <p>Por favor, selecione o tipo de disparo para a campanha única.</p> <!-- CAMPAIGN.MODAL.DESCRIPTION -->
        <div class="flex justify-center gap-4 mt-4">
  <woot-button
    class="hover-woot"
    color-scheme="secondary"
    @click="handleSingleBlast"
  >
    Disparo Único <!-- CAMPAIGN.MODAL.BUTTON_SINGLE -->
  </woot-button>
  <woot-button
    class="hover-woot"
    color-scheme="secondary"
    @click="handleFlowBlast"
  >
    Envio de Fluxo <!-- CAMPAIGN.MODAL.BUTTON_FLOW -->
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
      showComponentModal: false, // Modal para componentes
      currentComponent: null, // Componente atual carregado dinamicamente
    };
  },
  computed: {
    buttonText() {
      if (this.isOngoingType) {
        return 'Campanha em andamento';
      }
      return 'Criar Campanha';
    },
    isOneOffType() {
      return !this.isOngoingType;
    },
  },
  mounted() {
    this.$store.dispatch('campaigns/get');
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
  },
};
</script>
<style scoped>
.hover-woot:hover {
  background-color: var(--color-woot);
  color: white;
}
</style>

