/* eslint-disable */

<template>
  <woot-modal :show.sync="show" :on-close="onClose" class="campaign-modal-container">
    <div class="h-auto overflow-auto flex flex-col">
      <woot-modal-header
        :header-title="$t('CAMPAIGN.ADD.TITLE')"
        :header-content="$t('CAMPAIGN.ADD.DESC')"
      />
      <form class="flex flex-col w-full" @submit.prevent="addCampaign">
        <div class="w-full">
          <woot-input
            v-model="title"
            :label="$t('CAMPAIGN.ADD.FORM.TITLE.LABEL')"
            type="text"
            :class="{ error: $v.title.$error }"
            :error="$v.title.$error ? $t('CAMPAIGN.ADD.FORM.TITLE.ERROR') : ''"
            :placeholder="$t('CAMPAIGN.ADD.FORM.TITLE.PLACEHOLDER')"
            @blur="$v.title.$touch"
          />

          <div v-if="isOngoingType" class="editor-wrap">
            <label>
              {{ $t('CAMPAIGN.ADD.FORM.MESSAGE.LABEL') }}
            </label>
            <div>
              <woot-message-editor
                v-model="message"
                class="message-editor"
                :class="{ editor_warning: $v.message.$error }"
                :placeholder="$t('CAMPAIGN.ADD.FORM.MESSAGE.PLACEHOLDER')"
                @blur="$v.message.$touch"
              />
              <span v-if="$v.message.$error" class="editor-warning__message">
                {{ $t('CAMPAIGN.ADD.FORM.MESSAGE.ERROR') }}
              </span>
            </div>
          </div>
          <!-- Campo de mensagem para campanhas one-off -->
          <!--
          <label v-else :class="{ error: $v.message.$error }">
            {{ $t('CAMPAIGN.ADD.FORM.MESSAGE.LABEL') }}
            <textarea
              v-model="message"
              rows="5"
              type="text"
              :placeholder="$t('CAMPAIGN.ADD.FORM.MESSAGE.PLACEHOLDER')"
              @blur="$v.message.$touch"
            />
            <span v-if="$v.message.$error" class="message">
              {{ $t('CAMPAIGN.ADD.FORM.MESSAGE.ERROR') }}
            </span>
          </label>
  -->
          <label :class="{ error: $v.selectedInbox.$error }">
            {{ $t('CAMPAIGN.ADD.FORM.INBOX.LABEL') }}
            <select v-model="selectedInbox" @change="onChangeInbox($event)">
              <option v-for="item in inboxes" :key="item.name" :value="item.id">
                {{ item.name }}
              </option>
            </select>
            <span v-if="$v.selectedInbox.$error" class="message">
              {{ $t('CAMPAIGN.ADD.FORM.INBOX.ERROR') }}
            </span>
          </label>

          <label
            v-if="isOneOffType"
            class="multiselect-wrap--small"
            :class="{ error: $v.selectedAudience.$error }"
          >
            {{ $t('CAMPAIGN.ADD.FORM.AUDIENCE.LABEL') }}
            <multiselect
              v-model="selectedAudience"
              :options="audienceList"
              track-by="id"
              label="title"
              :multiple="true"
              :close-on-select="false"
              :clear-on-select="false"
              :hide-selected="true"
              :placeholder="$t('CAMPAIGN.ADD.FORM.AUDIENCE.PLACEHOLDER')"
              selected-label
              :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
              :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
              @blur="$v.selectedAudience.$touch"
              @select="$v.selectedAudience.$touch"
            />
            <span v-if="$v.selectedAudience.$error" class="message">
              {{ $t('CAMPAIGN.ADD.FORM.AUDIENCE.ERROR') }}
            </span>
          </label>

          <label
            v-if="isOngoingType"
            :class="{ error: $v.selectedSender.$error }"
          >
            {{ $t('CAMPAIGN.ADD.FORM.SENT_BY.LABEL') }}
            <select v-model="selectedSender">
              <option
                v-for="sender in sendersAndBotList"
                :key="sender.name"
                :value="sender.id"
              >
                {{ sender.name }}
              </option>
            </select>
            <span v-if="$v.selectedSender.$error" class="message">
              {{ $t('CAMPAIGN.ADD.FORM.SENT_BY.ERROR') }}
            </span>
          </label>

          <label v-if="isOneOffType">
            {{ $t('CAMPAIGN.ADD.FORM.SCHEDULED_AT.LABEL') }}
            <woot-date-time-picker
              :value="scheduledAt"
              :confirm-text="$t('CAMPAIGN.ADD.FORM.SCHEDULED_AT.CONFIRM')"
              :placeholder="$t('CAMPAIGN.ADD.FORM.SCHEDULED_AT.PLACEHOLDER')"
              @change="onChange"
            />
          </label>

          <woot-input
            v-if="isOngoingType"
            v-model="endPoint"
            :label="$t('CAMPAIGN.ADD.FORM.END_POINT.LABEL')"
            type="text"
            :class="{ error: $v.endPoint.$error }"
            :error="
              $v.endPoint.$error ? $t('CAMPAIGN.ADD.FORM.END_POINT.ERROR') : ''
            "
            :placeholder="$t('CAMPAIGN.ADD.FORM.END_POINT.PLACEHOLDER')"
            @blur="$v.endPoint.$touch"
          />
          <woot-input
            v-if="isOngoingType"
            v-model="timeOnPage"
            :label="$t('CAMPAIGN.ADD.FORM.TIME_ON_PAGE.LABEL')"
            type="text"
            :class="{ error: $v.timeOnPage.$error }"
            :error="
              $v.timeOnPage.$error
                ? $t('CAMPAIGN.ADD.FORM.TIME_ON_PAGE.ERROR')
                : ''
            "
            :placeholder="$t('CAMPAIGN.ADD.FORM.TIME_ON_PAGE.PLACEHOLDER')"
            @blur="$v.timeOnPage.$touch"
          />
          <label v-if="isOngoingType">
            <input
              v-model="enabled"
              type="checkbox"
              value="enabled"
              name="enabled"
            />
            {{ $t('CAMPAIGN.ADD.FORM.ENABLED') }}
          </label>
          <label v-if="isOngoingType">
            <input
              v-model="triggerOnlyDuringBusinessHours"
              type="checkbox"
              value="triggerOnlyDuringBusinessHours"
              name="triggerOnlyDuringBusinessHours"
            />
            {{ $t('CAMPAIGN.ADD.FORM.TRIGGER_ONLY_BUSINESS_HOURS') }}
          </label>

          <label
            v-if="isOneOffType"
            class="select-wrap"
            :class="{ error: $v.selectedMacro.$error }"
          >
            {{ $t('CAMPAIGN.ADD.FORM.MACRO.LABEL') }}
            <a
              :href="macroUrl"
              target="_blank"
              rel="noopener noreferrer"
              class="create-macro-link"
            >
              Criar macro
            </a>
            <select v-model="selectedMacro" @change="$v.selectedMacro.$touch">
              <option value="">
                {{ $t('CAMPAIGN.ADD.FORM.MACRO.PLACEHOLDER') }}
              </option>
              <option
                v-for="macro in macrosList"
                :key="macro.id"
                :value="macro.id"
              >
                {{ macro.name }}
              </option>
            </select>
            <span v-if="$v.selectedMacro.$error" class="message">
              {{ $t('CAMPAIGN.ADD.FORM.MACRO.ERROR') }}
            </span>
          </label>

          <div v-if="isOneOffType" class="file-upload-section">
            <label>
              {{ $t('CAMPAIGN.ADD.FORM.CONTACT_LIST.LABEL') }}
              <input
                type="file"
                accept=".xlsx, .xls, .csv"
                @change="handleFileUpload"
              />
            </label>
            <p v-if="fileUploadError" class="error-message">
              {{ fileUploadError }}
            </p>
            <div v-if="validationMessages.length > 0" class="validation-messages">
              <p class="validation-title">{{ $t('CAMPAIGN.ADD.FORM.CONTACT_LIST.VALIDATION_TITLE') }}</p>
              <ul class="validation-list">
                <li v-for="(message, index) in validationMessages" :key="index" class="validation-item">
                  {{ message }}
                </li>
              </ul>
              <p v-if="hasMoreInvalidNumbers" class="more-invalid-note">
                {{ $t('CAMPAIGN.ADD.FORM.CONTACT_LIST.SHOWING_SAMPLE', {
                  shown: validationMessages.length,
                  total: totalInvalidNumbers
                }) }}
              </p>
            </div>
            <div v-if="contactCount" class="contact-list-info">
              <p class="contact-count">
                {{
                  $t('CAMPAIGN.ADD.FORM.CONTACT_LIST.CONTACT_COUNT', {
                    count: contactCount,
                  })
                }}
              </p>
              <button class="delete-button" @click="removeContactList">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="24"
                  height="24"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <polyline points="3 6 5 6 21 6" />
                  <path
                    d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"
                  />
                  <line x1="10" y1="11" x2="10" y2="17" />
                  <line x1="14" y1="11" x2="14" y2="17" />
                </svg>
              </button>
            </div>
          </div>

          <!-- Checkbox temporariamente comentado
          <div class="row">
            <div class="medium-12 columns">
              <div class="settings-section">
                <label class="checkbox-wrap">
                  <input
                    v-model="showInSystem"
                    type="checkbox"
                    :checked="showInSystem"
                  />
                  {{ $t('CAMPAIGN.ADD.FORM.SHOW_IN_SYSTEM.LABEL') }}
                  <span
                    v-tooltip="{
                      content: $t('CAMPAIGN.ADD.FORM.SHOW_IN_SYSTEM.TOOLTIP'),
                      placement: 'top',
                      appendTo: 'body'
                    }"
                    class="help-icon"
                  >
                    <i class="ion-help-circled" />
                  </span>
                </label>
              </div>
            </div>
          </div>
          -->
        </div>

        <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
          <woot-button :is-loading="uiFlags.isCreating">
            {{ $t('CAMPAIGN.ADD.CREATE_BUTTON_TEXT') }}
          </woot-button>
          <woot-button variant="clear" @click.prevent="onClose">
            {{ $t('CAMPAIGN.ADD.CANCEL_BUTTON_TEXT') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { required } from 'vuelidate/lib/validators';
import { useAlert } from 'dashboard/composables';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import campaignMixin from 'shared/mixins/campaignMixin';
import WootDateTimePicker from 'dashboard/components/ui/DateTimePicker.vue';
import { CAMPAIGNS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import * as XLSX from 'xlsx';
import { validatePhoneList } from './utils/phoneValidation';

export default {
  components: {
    WootDateTimePicker,
    WootMessageEditor,
  },

  mixins: [campaignMixin],
  data() {
    return {
      title: '',
      message: '.',
      selectedSender: 0,
      selectedInbox: null,
      endPoint: '',
      timeOnPage: 10,
      show: true,
      enabled: true,
      triggerOnlyDuringBusinessHours: false,
      scheduledAt: null,
      selectedAudience: [],
      senderList: [],
      selectedMacro: '',
      contactList: [],
      fileUploadError: '',
      contactCount: 0,
      invalidNumbers: [],
      validationMessages: [],
      hasMoreInvalidNumbers: false,
      totalInvalidNumbers: 0,
      showInSystem: true,
    };
  },

  validations() {
    const commonValidations = {
      title: {
        required,
      },
      message: {
        required,
      },
      selectedInbox: {
        required,
      },
    };

    const audienceOrContactListRequired = {
      required: value => value.length > 0 || this.contactList.length > 0,
    };

    if (this.isOngoingType) {
      return {
        ...commonValidations,
        selectedSender: {
          required,
        },
        endPoint: {
          required,
          shouldBeAValidURLPattern(value) {
            return this.shouldBeAValidURLPattern(value);
          },
          shouldStartWithHTTP(value) {
            if (value) {
              return (
                value.startsWith('https://') || value.startsWith('http://')
              );
            }
            return false;
          },
        },
        timeOnPage: {
          required,
        },
      };
    }
    if (this.isOneOffType) {
      return {
        ...commonValidations,
        selectedAudience: audienceOrContactListRequired,
        selectedMacro: {
          required,
        },
      };
    }
    return commonValidations;
  },
  computed: {
    ...mapGetters({
      uiFlags: 'campaigns/getUIFlags',
      audienceList: 'labels/getLabels',
      macrosList: 'macros/getMacros',
    }),
    inboxes() {
      if (this.isOngoingType) {
        return this.$store.getters['inboxes/getWebsiteInboxes'];
      }
      return [
        ...this.$store.getters['inboxes/getSMSInboxes'],
        ...this.$store.getters['inboxes/getApiInboxes'],
      ];
    },
    sendersAndBotList() {
      return [
        {
          id: 0,
          name: 'Bot',
        },
        ...this.senderList,
      ];
    },
    macroUrl() {
      if (typeof window !== 'undefined') {
        return `${window.location.origin}/app/accounts/${this.$route.params.accountId}/settings/macros`;
      }
      return '#';
    },
  },
  mounted() {
    this.$track(CAMPAIGNS_EVENTS.OPEN_NEW_CAMPAIGN_MODAL, {
      type: this.campaignType,
    });
    this.fetchMacros();
    this.$nextTick(() => {
      const tooltips = document.querySelectorAll('.v-tooltip');
      tooltips.forEach(tooltip => {
        tooltip.style.zIndex = '100000';
      });
    });
  },
  methods: {
    onClose() {
      this.$emit('on-close');
    },
    onChange(value) {
      this.scheduledAt = value;
    },
    async onChangeInbox() {
      try {
        const response = await this.$store.dispatch('inboxMembers/get', {
          inboxId: this.selectedInbox,
        });
        const {
          data: { payload: inboxMembers },
        } = response;
        this.senderList = inboxMembers;
      } catch (error) {
        const errorMessage =
          error?.response?.message || this.$t('CAMPAIGN.ADD.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
    async fetchMacros() {
      await this.$store.dispatch('macros/get');
    },
    handleFileUpload(event) {
      const file = event.target.files[0];
      const reader = new FileReader();

      reader.onload = e => {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });

        const firstSheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[firstSheetName];
        const jsonData = XLSX.utils.sheet_to_json(worksheet);

        // Variações possíveis dos nomes das colunas
        const possibleNumberColumns = ['numeros', 'numero', 'Número', 'número', 'nUmeros'];
        const possibleNameColumns = ['nome', 'Nome', 'Nomes'];
        const possibleVariableColumns = ['variavel', 'variável', 'Variavel', 'Variável'];

        // Função para encontrar a chave correta
        function findColumn(possibleColumns, row) {
          return possibleColumns.find(column => column in row);
        }

        // Encontrar as colunas correspondentes no jsonData
        const numberColumn = findColumn(possibleNumberColumns, jsonData[0]);
        const nameColumn = findColumn(possibleNameColumns, jsonData[0]);
        const variableColumn = findColumn(possibleVariableColumns, jsonData[0]);

        if (jsonData.length > 0 && numberColumn) {
          const contacts = jsonData.map(row => ({
            numero: row[numberColumn],
            nome: row[nameColumn] || '',
            variavel: row[variableColumn] || ''
          })).filter(contact => contact.numero);

          // Validar os números de telefone
          const validationResult = validatePhoneList(contacts);
          
          if (validationResult.hasErrors) {
            // Verificar se há muitos números inválidos
            if (validationResult.totalInvalid > 50) {
              this.fileUploadError = this.$t('CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_TOO_MANY_INVALID', {
                count: validationResult.totalInvalid
              });
            } else {
              this.fileUploadError = this.$t('CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_INVALID_NUMBERS', {
                count: validationResult.totalInvalid,
                total: contacts.length
              });
            }
            
            // Armazenar os números inválidos e suas mensagens
            this.invalidNumbers = validationResult.invalidNumbers;
            
            // Mostrar apenas uma amostra dos números inválidos
            this.validationMessages = validationResult.limitedInvalidNumbers.map(contact => 
              `${contact.numero}: ${this.$t(contact.messageKey)}`
            );
            
            this.hasMoreInvalidNumbers = validationResult.hasMoreInvalid;
            this.totalInvalidNumbers = validationResult.totalInvalid;
            
            // Limpar a lista de contatos se houver números inválidos
            this.contactList = [];
            this.contactCount = 0;
          } else {
            this.contactList = validationResult.validNumbers;
            this.contactCount = this.contactList.length;
            this.fileUploadError = '';
            this.invalidNumbers = [];
            this.validationMessages = [];
            this.hasMoreInvalidNumbers = false;
            this.totalInvalidNumbers = 0;
          }
          
          this.$v.selectedAudience.$touch();
        } else {
          this.fileUploadError = this.$t('CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_NO_COLUMN');
          this.contactList = [];
          this.contactCount = 0;
          this.invalidNumbers = [];
          this.validationMessages = [];
          this.hasMoreInvalidNumbers = false;
          this.totalInvalidNumbers = 0;
        }
      };

      reader.readAsArrayBuffer(file);
    },
    removeContactList() {
      this.contactList = [];
      this.contactCount = 0;
      this.$v.selectedAudience.$touch();
    },
    getCampaignDetails() {
      let campaignDetails = null;
      if (this.isOngoingType) {
        campaignDetails = {
          title: this.title,
          message: this.message,
          inbox_id: this.selectedInbox,
          sender_id: this.selectedSender || null,
          enabled: this.enabled,
          trigger_only_during_business_hours: this.triggerOnlyDuringBusinessHours,
          trigger_rules: {
            url: this.endPoint,
            time_on_page: this.timeOnPage,
            show_in_system: this.showInSystem,
          },
        };
      } else {
        const selectedMacroObj = this.macrosList.find(
          macro => macro.id === Number(this.selectedMacro)
        );

        const audience =
          this.contactList.length > 0
            ? this.contactList.map(contact => ({
                id: contact.numero,
                type: 'Contact',
                nome: contact.nome,
                variavel: contact.variavel
              }))
            : this.selectedAudience.map(item => ({
                id: item.id,
                type: 'Label'
              }));

        campaignDetails = {
          title: this.title,
          message: this.message,
          inbox_id: this.selectedInbox,
          scheduled_at: this.scheduledAt,
          audience,
          trigger_rules: {
            macro_id: this.selectedMacro || '',
            show_in_system: this.showInSystem,
          },
          contact_list: this.contactList,
        };
      }
      return campaignDetails;
    },
    async addCampaign() {
      this.$v.$touch();

      // Se for campanha contínua, remova a verificação de público
      if (this.isOngoingType) {
        // Prossiga com o salvamento mesmo sem público
        const campaignDetails = this.getCampaignDetails();
        await this.$store.dispatch('campaigns/create', campaignDetails);
        return;
      }

      // Validação para campanhas one-off
      if (this.$v.$invalid) {
        if (
          this.contactList.length === 0 &&
          this.selectedAudience.length === 0
        ) {
          useAlert(this.$t('CAMPAIGN.ADD.FORM.ERROR_NO_AUDIENCE_OR_CONTACTS'));
        }
        return;
      }

      // Validar os números de telefone antes de salvar
      if (this.contactList.length > 0) {
        const validationResult = validatePhoneList(this.contactList);
        if (validationResult.hasErrors) {
          // Verificar se há muitos números inválidos
          if (validationResult.totalInvalid > 50) {
            useAlert(this.$t('CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_TOO_MANY_INVALID', {
              count: validationResult.totalInvalid
            }));
          } else {
            useAlert(this.$t('CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_INVALID_NUMBERS', {
              count: validationResult.totalInvalid,
              total: this.contactList.length
            }));
          }
          
          // Atualizar o estado para mostrar os erros
          this.invalidNumbers = validationResult.invalidNumbers;
          this.validationMessages = validationResult.limitedInvalidNumbers.map(contact => 
            `${contact.numero}: ${this.$t(contact.messageKey)}`
          );
          this.hasMoreInvalidNumbers = validationResult.hasMoreInvalid;
          this.totalInvalidNumbers = validationResult.totalInvalid;
          
          return;
        }
      }

      try {
        const campaignDetails = this.getCampaignDetails();
        await this.$store.dispatch('campaigns/create', campaignDetails);

        this.$track(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
          type: this.campaignType,
        });

        useAlert(this.$t('CAMPAIGN.ADD.API.SUCCESS_MESSAGE'));
        this.onClose();
      } catch (error) {
        const errorMessage =
          error?.response?.message || this.$t('CAMPAIGN.ADD.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<style lang="scss" scoped>
.campaign-modal-container {
  position: relative;
  z-index: 10; // Base z-index para o modal
  
  :deep(.modal-container) {
    z-index: 11;
  }
}

// Garante que o modal esteja acima de outros elementos mas abaixo dos tooltips
:deep(.woot-modal--modal) {
  z-index: 1000;
}

::v-deep .ProseMirror-woot-style {
  height: 5rem;
}

.message-editor {
  @apply px-3;

  ::v-deep {
    .ProseMirror-menubar {
      @apply rounded-tl-[4px];
    }
  }
}

.file-upload-section {
  margin-bottom: 1rem;

  .error-message {
    color: red;
    margin-top: 0.5rem;
  }

  .contact-list-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 0.5rem;

    .contact-count {
      font-weight: bold;
    }

    .delete-button {
      background: none;
      border: none;
      cursor: pointer;
      padding: 0;
      color: var(--color-body);
      transition: color 0.3s ease;

      &:hover {
        color: var(--color-error);
      }

      svg {
        width: 20px;
        height: 20px;
      }
    }
  }
}

.create-macro-link {
  display: inline;
  font-size: 0.750rem; /* Um pouco menor que o padrão para parecer sutil */
  color: var(--color-woot); /* Use a cor primária que já está em seu sistema para manter a consistência */
  text-decoration: underline;
  cursor: pointer;
  transition: color 0.3s ease; /* Transição suave na cor ao passar o mouse */

  &:hover {
    color: var(--color-primary-700); /* Um tom mais escuro para diferenciar no hover */
  }
}

.validation-messages {
  margin-top: 1rem;
  padding: 0.5rem;
  border-left: 3px solid var(--color-error);
  border-radius: 4px;

  .validation-title {
    font-weight: bold;
    margin-bottom: 0.5rem;
    color: var(--color-error);
  }

  .validation-list {
    list-style-type: none;
    padding: 0;
    margin: 0;
    max-height: 150px;
    overflow-y: auto;
  }

  .validation-item {
    padding: 0.25rem 0;
    color: var(--color-error);
    font-size: 0.875rem;
    border-bottom: 1px solid var(--b-100);
  }

  .more-invalid-note {
    margin-top: 0.5rem;
    font-size: 0.75rem;
    font-style: italic;
    color: var(--s-600);
  }
}

.checkbox-wrap {
  display: flex;
  align-items: center;
  gap: var(--space-smaller);
  cursor: pointer;

  input[type="checkbox"] {
    margin: 0;
    cursor: pointer;
  }
}

.settings-section {
  padding: var(--space-normal) 0;
  position: relative;
  z-index: 2;
}

.help-icon {
  display: inline-flex;
  margin-left: var(--space-smaller);
  color: var(--color-gray-medium);
  font-size: var(--font-size-small);
  cursor: help;
  transition: color 0.2s ease;

  &:hover {
    color: var(--color-primary-dark);
  }
}

</style>

<style lang="scss">
/* Estilos não escoped para afetar elementos fora do componente */
body > .tooltip {
  z-index: 999999 !important;
  opacity: 1 !important;
  visibility: visible !important;
}

body > .v-tooltip-container {
  z-index: 999999 !important;
}
</style>

