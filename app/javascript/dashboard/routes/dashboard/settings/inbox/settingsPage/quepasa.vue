<template>
  <div class="qr-code-container">
    <LoadingState v-if="loading" />
    <div v-else>
      <div v-if="isWhatsappConnected">
        <div v-if="whatsappStatusMessage" :class="statusClass">
          <p>{{ whatsappStatusMessage }}</p>
        </div>
        <woot-submit-button
          :loading="isUpdatingLocal"
          button-text="Desconectar"
          class="disconnect-button"
          @click="handleDisconnect"
        />
        <div class="spacer" />
        <div class="checkout">
          <label>
            <input
              v-model="enableGroup"
              type="checkbox"
              @change="handleCheckoutChange"
            />
            Habilitar Grupo
          </label>
          <label>
            <input
              v-model="enableAgentName"
              type="checkbox"
              @change="handleCheckoutChange"
            />
            Habilitar nome do atendente na mensagem
          </label>
        </div>
        <GroupMessage v-if="enableGroup" />
      </div>
      <div v-else>
        <QrCodeGenerator
          v-if="qrcodeImage"
          :qrcode-image="qrcodeImage"
          :time-left="timeLeft"
          @refresh="refreshQrCode"
        />
        <div v-else class="align-left">
          <h2>Clique no botão abaixo para gerar Qr Code</h2>
          <p>
            Observação: lembre-se que o Qr Code terá validade apenas de 20
            segundos, esteja com o celular em mãos para digitalizar o código.
          </p>
          <woot-submit-button
            :loading="isUpdatingLocal"
            button-text="Gerar Qr Code"
            class="generate-button"
            @click="generateQrCode"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import LoadingState from '../../../../../components/widgets/LoadingState.vue';
import GroupMessage from './GroupMessage.vue';
import QrCodeGenerator from './QrCodeGenerator.vue';

export default {
  components: {
    LoadingState,
    GroupMessage,
    QrCodeGenerator,
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      isUpdatingLocal: false,
      qrcodeImage: null,
      timeLeft: 20,
      whatsappStatusMessage: null,
      statusClass: null,
      isWhatsappConnected: false,
      loading: false,
      enableGroup: false,
      enableAgentName: false,
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      uiFlags: 'inboxes/getUIFlags',
      accountId: 'getCurrentAccountId',
      account: 'getCurrentAccount',
    }),
  },
  mounted() {
    this.sendPayloadToWebhook('modal_opened');
  },
  methods: {
    async sendPayloadToWebhook(event) {
      this.isUpdatingLocal = true;
      try {
        const payload = this.buildPayload(event);
        const response = await this.postToWebhook(event, payload);

        this.handleResponse(event, response);
      } catch (error) {
        this.handleError(error);
      } finally {
        this.isUpdatingLocal = false;
      }
    },

    buildPayload(event) {
      return {
        event,
        currentUser: this.currentUser,
        accountId: this.accountId,
        account: this.account,
        inbox: this.inbox,
        enableGroup: this.enableGroup,
        enableAgentName: this.enableAgentName,
        timestamp: new Date().toISOString(),
      };
    },

    async postToWebhook(event, payload) {
      return axios.post(
        'http://localhost:8080/http://173.249.22.227:5678/webhook/quepasa2',
        payload,
        { responseType: event === 'qrcode_created' ? 'arraybuffer' : 'json' }
      );
    },

    handleResponse(event, response) {
      if (response.status === 200) {
        this.updateStateFromResponse(event, response);
      }

      if (event === 'qrcode_created') {
        this.qrcodeImage = this.convertToBase64(response.data);
        this.startTimer();
      }
    },

    updateStateFromResponse(event, response) {
      const numero = response.headers.numero || 'Número não encontrado';
      const grupo = response.headers.grupo === 'true';
      const name_agent = response.headers.name_agent === 'true';

      if (event === 'modal_opened') {
        this.isWhatsappConnected = true;
        this.whatsappStatusMessage = `WhatsApp está conectado ✅. Número: ${numero}`;
        this.statusClass = 'alert alert-success';

        this.enableGroup = grupo;
        this.enableAgentName = name_agent;
      } else if (event === 'disconnect') {
        this.refreshModal();
      }
    },

    convertToBase64(responseData) {
      return `data:image/png;base64,${btoa(
        new Uint8Array(responseData).reduce(
          (acc, byte) => acc + String.fromCharCode(byte),
          ''
        )
      )}`;
    },

    handleError(error) {
      if (error.response && error.response.status === 503) {
        this.whatsappStatusMessage = 'WhatsApp está desconectado ❌';
        this.statusClass = 'alert alert-danger';
        useAlert(this.whatsappStatusMessage);
      } else {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },

    handleDisconnect() {
      this.sendPayloadToWebhook('disconnect');
    },

    generateQrCode() {
      this.sendPayloadToWebhook('qrcode_created');
    },

    refreshModal() {
      this.isWhatsappConnected = false;
      this.qrcodeImage = null;
      this.whatsappStatusMessage = null;
      this.statusClass = null;
      this.sendPayloadToWebhook('modal_opened');
    },

    startTimer() {
      this.timeLeft = 20;
      this.timer = setInterval(() => {
        if (this.timeLeft > 0) {
          this.timeLeft -= 1;
        } else {
          clearInterval(this.timer);
          this.loading = true;
          setTimeout(() => {
            this.loading = false;
            this.clearQrCode();
            this.sendPayloadToWebhook('verify_connection');
            this.refreshModal();
          }, 3000);
        }
      }, 1000);
    },

    clearQrCode() {
      clearInterval(this.timer);
      this.qrcodeImage = null;
      this.timeLeft = 0;
    },

    handleCheckoutChange() {
      this.sendPayloadToWebhook('inbox_update');
      useAlert('Canal de entrada atualizado');
    },
  },
};
</script>

<style scoped>
.qr-code-container {
  text-align: left;
  padding: 20px;
  max-width: 600px;
  margin: auto;
}

.qr-code-container h2 {
  font-size: 20px;
  margin-bottom: 10px;
}

.qr-code-container p {
  font-size: 14px;
  color: inherit;
}

.generate-button {
  margin-top: 20px;
}

.disconnect-button {
  margin-top: 10px;
  width: auto;
  background-color: #f56565;
  color: #fff;
}

.spacer {
  margin-top: 20px;
}

.align-left {
  text-align: left;
}

.qr-content {
  display: flex;
  justify-content: flex-start;
  align-items: center;
}

.qrcode {
  max-width: 200px;
  max-height: 200px;
}

.qr-instructions {
  margin-left: 20px;
  text-align: left;
  font-size: 14px;
  color: inherit;
}

.timer {
  margin-top: 10px;
  font-size: 14px;
  color: inherit;
  font-weight: bold;
}

.alert {
  margin-top: 20px;
  padding: 10px;
  border-radius: 5px;
  text-align: center;
}

.alert-danger {
  background-color: #ffcccc;
  color: #cc0000;
  border: 1px solid #cc0000;
}

.alert-success {
  background-color: #ccffcc;
  color: #006600;
  border: 1px solid #006600;
}

.checkout label {
  display: block;
  margin-top: 10px;
  font-size: 14px;
  color: inherit;
}

.group-message {
  margin-top: 10px;
  font-size: 14px;
  color: inherit;
}
</style>
