/* eslint-disable vue/html-closing-bracket-newline */
<template>
  <div class="h-full">
    <div v-if="loading" class="flex flex-col items-center justify-center p-12">
      <LoadingState />
      <p class="mt-4 text-slate-600 dark:text-slate-400 font-medium text-sm">
        Carregando...
      </p>
    </div>

    <div v-else class="space-y-4">
      <!-- Connected State -->
      <div v-if="isWhatsappConnected" class="space-y-4">
        <SettingsSection
          title="Status da Conexão"
          sub-title="Gerencie sua conexão ativa do WhatsApp e o estado do canal."
        >
          <div v-if="whatsappStatusMessage" :class="statusClass" role="alert">
            <p class="font-medium text-sm">{{ whatsappStatusMessage }}</p>
          </div>

          <div class="mt-4">
            <woot-button
              variant="smooth"
              color-scheme="danger"
              class="w-auto"
              :loading="isUpdatingLocal"
              @click="sendPayloadToWebhook('disconnect')"
            >
              Desconectar
            </woot-button>
          </div>
        </SettingsSection>

        <SettingsSection
          title="Configurações Adicionais"
          sub-title="Personalize como as mensagens e grupos são tratados neste canal."
        >
          <div class="flex flex-col gap-2">
            <div class="flex items-center gap-2">
              <input
                id="enableGroup"
                v-model="enableGroup"
                type="checkbox"
                @change="handleCheckoutChange"
              />
              <label for="enableGroup" class="cursor-pointer text-sm">
                Habilitar Grupo
              </label>
            </div>

            <div class="flex items-center gap-2">
              <input
                id="enableAgentName"
                v-model="enableAgentName"
                type="checkbox"
                @change="handleCheckoutChange"
              />
              <label for="enableAgentName" class="cursor-pointer text-sm">
                Habilitar nome do atendente na mensagem
              </label>
            </div>

            <div class="flex items-center gap-2">
              <input
                id="enableSingle"
                v-model="enableSingle"
                type="checkbox"
                @change="handleCheckoutChange"
              />
              <label for="enableSingle" class="cursor-pointer text-sm">
                Conversa Única
              </label>
            </div>
          </div>

          <div v-if="enableGroup" class="mt-4">
            <p class="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
              Para saber como visualizar os grupos, acesse
              <a
                href="https://app.manytalks.com.br/hc/manytalks/articles/1708550110-como-visualizar-os-grupos"
                target="_blank"
                class="underline hover:text-primary-500 transition"
              >
                este link
              </a>
            </p>
          </div>
        </SettingsSection>
      </div>

      <!-- Disconnected State (QR Code) -->
      <div v-else>
        <SettingsSection
          title="Conectar WhatsApp"
          sub-title="Escaneie o QR Code abaixo para conectar sua conta."
        >
          <div v-if="qrcodeImage" class="flex flex-col md:flex-row gap-8 mt-4 items-start">
            <div class="bg-white p-2 border border-slate-200 dark:border-slate-800 rounded-sm">
              <img :src="qrcodeImage" alt="QR Code" class="w-48 h-48 block" />
            </div>
            
            <div class="flex-1 space-y-3">
              <p class="text-sm text-slate-700 dark:text-slate-300">
                Lembre-se que o QR Code terá validade apenas de <strong>{{ timeLeft }} segundos</strong>.
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                Pode ser necessário escanear novamente caso expire.
              </p>
            </div>
          </div>

          <div v-else class="mt-4">
            <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
              Clique no botão abaixo para gerar um QR Code. Ele expira rapidamente por motivos de segurança.
            </p>
            <woot-button
              :loading="isUpdatingLocal"
              @click="sendPayloadToWebhook('qrcode_created')"
            >
              Gerar QR Code
            </woot-button>
          </div>
        </SettingsSection>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import LoadingState from '../../../../../components/widgets/LoadingState.vue';
import SettingsSection from '../../../../../components/SettingsSection.vue';

export default {
  components: {
    LoadingState,
    SettingsSection,
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
      enableSingle: false, // Opção de conversa única
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
          enableSingle: this.enableSingle, // Inclui conversa única no payload
          timestamp: new Date().toISOString(),
        };

        const response = await axios.post(
          process.env.WEBHOOK_URL, // Usando a URL do .env
          payload,
          { responseType: event === 'qrcode_created' ? 'arraybuffer' : 'json' }
        );

        if (response.status === 200) {
          const numero = response.data?.numero || 'Número não encontrado';
          const grupo =
            response.data?.grupo === true || response.data?.grupo === 'true';
          const name_agent =
            response.data?.name_agent === true ||
            response.data?.name_agent === 'true';
          const single =
            response.data?.single === true || response.data?.single === 'true';

          if (event === 'modal_opened') {
            this.isWhatsappConnected = true;
            this.whatsappStatusMessage = `WhatsApp está conectado ✅. Número: ${numero}`;
            this.statusClass =
              'p-2 mb-2 rounded-sm bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-300 border border-green-200 dark:border-green-800';

            // Atualiza os checkboxes com as informações do webhook
            this.enableGroup = grupo;
            this.enableAgentName = name_agent;
            this.enableSingle = single;
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
        this.statusClass =
          'p-2 mb-2 rounded-sm bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-300 border border-red-200 dark:border-red-800';
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
.spacer {
  margin-top: 20px;
}
</style>
