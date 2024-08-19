/* eslint-disable vue/html-closing-bracket-newline */
<template>
  <div class="qr-code-container">
    <div v-if="loading">
      <p>Carregando...</p>
      <LoadingState />
    </div>
    <div v-else>
      <div v-if="isWhatsappConnected">
        <div v-if="whatsappStatusMessage" :class="statusClass">
          <p>{{ whatsappStatusMessage }}</p>
        </div>
        <woot-submit-button
          :loading="isUpdatingLocal"
          :button-text="'Desconectar'"
          class="disconnect-button"
          @click="sendPayloadToWebhook('disconnect')"
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
        <div v-if="enableGroup" class="group-message">
          <p>
            Para saber como visualizar os grupos, acesse
            <a
              href="https://app.manytalks.com.br/hc/manytalks/articles/1708550110-como-visualizar-os-grupos"
              target="_blank"
            >
              este link
            </a>
          </p>
        </div>
      </div>
      <div v-else>
        <div v-if="qrcodeImage" class="qr-content">
          <img :src="qrcodeImage" alt="QR Code" class="qrcode" />
          <div class="qr-instructions">
            <p>
              Observação: lembre-se que o Qr Code terá validade apenas de 20
              segundos, esteja com o celular em mãos para digitalizar o código.
            </p>
            <div class="timer">
              <br />
              <strong>{{ timeLeft }} segundos restantes</strong>
            </div>
          </div>
        </div>
        <div v-else class="align-left">
          <h2>Clique no botão abaixo para gerar Qr Code</h2>
          <p>
            Observação: lembre-se que o Qr Code terá validade apenas de 20
            segundos, esteja com o celular em mãos para digitalizar o código.
          </p>
          <woot-submit-button
            :loading="isUpdatingLocal"
            :button-text="'Gerar Qr Code'"
            class="generate-button"
            @click="sendPayloadToWebhook('qrcode_created')"
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

export default {
  components: {
    LoadingState,
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
      timer: null,
      whatsappStatusMessage: null,
      statusClass: null,
      isWhatsappConnected: false,
      loading: false, // Variável para controlar o estado de carregamento
      enableGroup: false, // Opção de habilitar grupo
      enableAgentName: false, // Opção de habilitar nome do atendente
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
    // Correções aplicadas no método sendPayloadToWebhook:
    async sendPayloadToWebhook(event) {
      this.isUpdatingLocal = true;

      try {
        const payload = {
          event: event,
          currentUser: this.currentUser,
          accountId: this.accountId,
          account: this.account,
          inbox: this.inbox,
          enableGroup: this.enableGroup, // Inclui opção de grupo no payload
          enableAgentName: this.enableAgentName, // Inclui nome do atendente no payload
          timestamp: new Date().toISOString(),
        };

        const response = await axios.post(
          process.env.WEBHOOK_URL, // Usando a URL do .env
          payload,
          { responseType: event === 'qrcode_created' ? 'arraybuffer' : 'json' }
        );

        if (response.status === 200) {
          const numero = response.headers.numero || 'Número não encontrado';
          const grupo = response.headers.grupo === 'true';
          const name_agent = response.headers.name_agent === 'true';

          if (event === 'modal_opened') {
            this.isWhatsappConnected = true;
            this.whatsappStatusMessage = `WhatsApp está conectado ✅. Número: ${numero}`;
            this.statusClass = 'alert alert-success';

            // Atualiza os checkboxes com as informações do webhook
            this.enableGroup = grupo;
            this.enableAgentName = name_agent;
          } else if (event === 'disconnect') {
            this.refreshModal();
          }
        }

        if (event === 'qrcode_created') {
          const base64Image = btoa(
            new Uint8Array(response.data).reduce(
              (data, byte) => data + String.fromCharCode(byte),
              ''
            )
          );
          this.qrcodeImage = `data:image/png;base64,${base64Image}`;
          this.startTimer();
        }
      } catch (error) {
        this.handleError(error);
      } finally {
        this.isUpdatingLocal = false;
      }
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

    refreshModal() {
      this.isWhatsappConnected = false;
      this.qrcodeImage = null;
      this.whatsappStatusMessage = null;
      this.statusClass = null;
      this.sendPayloadToWebhook('modal_opened');
    },

    async startTimer() {
      this.timeLeft = 20;
      this.timer = setInterval(async () => {
        if (this.timeLeft > 0) {
          this.timeLeft -= 1;
        } else {
          clearInterval(this.timer);
          this.loading = true; // Ativa o estado de carregamento
          /* eslint-disable no-promise-executor-return */
          await new Promise(resolve => setTimeout(resolve, 3000)); // Aguarda 3 segundos
          /* eslint-enable no-promise-executor-return */
          this.loading = false; // Desativa o estado de carregamento após 3 segundos
          this.clearQrCode();
          await this.sendPayloadToWebhook('verify_connection');
          this.refreshModal(); // Reinicia o modal
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
