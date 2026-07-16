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

          <campaign-audience-selector
            v-if="isOneOffType"
            v-model="audienceState"
            :show-error="$v.audienceState.$error"
            @input="$v.audienceState.$touch"
          />

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
import { INBOX_TYPES } from 'shared/mixins/inboxMixin';
import WootDateTimePicker from 'dashboard/components/ui/DateTimePicker.vue';
import CampaignAudienceSelector from './CampaignAudienceSelector.vue';
import { CAMPAIGNS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import { validatePhoneList } from './utils/phoneValidation';
import {
  defaultAudienceState,
  buildAudiencePayload,
  audienceStateIsComplete,
  AUDIENCE_SOURCES,
} from './utils/campaignAudienceHelper';

export default {
  components: {
    WootDateTimePicker,
    WootMessageEditor,
    CampaignAudienceSelector,
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
      audienceState: defaultAudienceState(),
      senderList: [],
      selectedMacro: '',
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

    const audienceComplete = {
      required: () => audienceStateIsComplete(this.audienceState),
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
        audienceState: audienceComplete,
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
      ].filter(
        inbox =>
          !(
            inbox.channel_type === INBOX_TYPES.WHATSAPP &&
            inbox.provider === 'whatsapp_cloud'
          )
      );
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
        const audience = buildAudiencePayload(this.audienceState);

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
          contact_list:
            this.audienceState.source === AUDIENCE_SOURCES.SPREADSHEET
              ? this.audienceState.contactList
              : [],
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
        if (!audienceStateIsComplete(this.audienceState)) {
          useAlert(this.$t('CAMPAIGN.ADD.FORM.ERROR_NO_AUDIENCE_OR_CONTACTS'));
        }
        return;
      }

      if (
        this.audienceState.source === AUDIENCE_SOURCES.SPREADSHEET &&
        this.audienceState.contactList.length > 0
      ) {
        const validationResult = validatePhoneList(this.audienceState.contactList);
        if (validationResult.hasErrors) {
          if (validationResult.totalInvalid > 50) {
            useAlert(this.$t('CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_TOO_MANY_INVALID', {
              count: validationResult.totalInvalid
            }));
          } else {
            useAlert(this.$t('CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_INVALID_NUMBERS', {
              count: validationResult.totalInvalid,
              total: this.audienceState.contactList.length
            }));
          }

          this.audienceState = {
            ...this.audienceState,
            validationMessages: validationResult.limitedInvalidNumbers.map(contact =>
              `${contact.numero}: ${this.$t(contact.messageKey)}`
            ),
            hasMoreInvalidNumbers: validationResult.hasMoreInvalid,
            totalInvalidNumbers: validationResult.totalInvalid,
          };

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
