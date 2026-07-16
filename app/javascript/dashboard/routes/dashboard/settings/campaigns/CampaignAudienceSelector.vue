<template>
  <div class="campaign-audience-selector">
    <p class="audience-label">
      {{ $t('CAMPAIGN.ADD.FORM.AUDIENCE.LABEL') }}
    </p>

    <div
      class="audience-tabs"
      role="tablist"
      :aria-label="$t('CAMPAIGN.ADD.FORM.AUDIENCE_SOURCE.ARIA')"
    >
      <button
        type="button"
        role="tab"
        class="audience-tab"
        :class="{ 'audience-tab--active': localState.source === 'labels' }"
        :aria-selected="localState.source === 'labels'"
        @click="switchSource('labels')"
      >
        {{ $t('CAMPAIGN.ADD.FORM.AUDIENCE_SOURCE.LABELS') }}
      </button>
      <button
        type="button"
        role="tab"
        class="audience-tab"
        :class="{ 'audience-tab--active': localState.source === 'spreadsheet' }"
        :aria-selected="localState.source === 'spreadsheet'"
        @click="switchSource('spreadsheet')"
      >
        {{ $t('CAMPAIGN.ADD.FORM.AUDIENCE_SOURCE.SPREADSHEET') }}
      </button>
    </div>

    <div
      v-if="localState.source === 'labels'"
      class="audience-panel"
      role="tabpanel"
    >
      <p class="audience-hint">
        {{ $t('CAMPAIGN.ADD.FORM.AUDIENCE_SOURCE.LABELS_HINT') }}
      </p>
      <label
        class="multiselect-wrap--small"
        :class="{ error: showError && !labelsValid }"
      >
        <multiselect
          v-model="localState.selectedLabels"
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
          @input="emitChange"
        />
        <span v-if="localState.selectedLabels.length" class="audience-count">
          {{
            $t('CAMPAIGN.ADD.FORM.AUDIENCE_SOURCE.LABELS_COUNT', {
              count: localState.selectedLabels.length,
            })
          }}
        </span>
      </label>
    </div>

    <div
      v-else
      class="audience-panel spreadsheet-panel"
      role="tabpanel"
    >
      <div class="spreadsheet-toolbar">
        <label class="file-picker">
          <input
            ref="fileInput"
            type="file"
            accept=".xlsx,.xls,.csv"
            class="file-picker-input"
            @change="handleFileUpload"
          />
          <span class="file-picker-label">
            {{ $t('CAMPAIGN.ADD.FORM.AUDIENCE_SOURCE.CHOOSE_FILE') }}
          </span>
        </label>
        <button
          type="button"
          class="template-download-link"
          @click="downloadTemplate"
        >
          {{ $t('CAMPAIGN.ADD.FORM.AUDIENCE_SOURCE.DOWNLOAD_TEMPLATE') }}
        </button>
      </div>

      <p v-if="localState.fileUploadError" class="error-message">
        {{ localState.fileUploadError }}
      </p>
      <div
        v-if="localState.validationMessages.length"
        class="validation-messages"
      >
        <p class="validation-title">
          {{ $t('CAMPAIGN.ADD.FORM.CONTACT_LIST.VALIDATION_TITLE') }}
        </p>
        <ul class="validation-list">
          <li
            v-for="(message, index) in localState.validationMessages"
            :key="index"
            class="validation-item"
          >
            {{ message }}
          </li>
        </ul>
        <p v-if="localState.hasMoreInvalidNumbers" class="more-invalid-note">
          {{
            $t('CAMPAIGN.ADD.FORM.CONTACT_LIST.SHOWING_SAMPLE', {
              shown: localState.validationMessages.length,
              total: localState.totalInvalidNumbers,
            })
          }}
        </p>
      </div>
      <div v-if="localState.contactCount" class="contact-list-info">
        <p class="contact-count">
          {{
            $t('CAMPAIGN.ADD.FORM.CONTACT_LIST.CONTACT_COUNT', {
              count: localState.contactCount,
            })
          }}
        </p>
        <button type="button" class="delete-button" @click="removeContactList">
          <fluent-icon icon="delete" size="16" />
        </button>
      </div>
    </div>

    <span v-if="showError && !isComplete" class="message">
      {{ $t('CAMPAIGN.ADD.FORM.ERROR_NO_AUDIENCE_OR_CONTACTS') }}
    </span>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import * as XLSX from 'xlsx';
import { validatePhoneList } from './utils/phoneValidation';
import {
  AUDIENCE_SOURCES,
  defaultAudienceState,
} from './utils/campaignAudienceHelper';

export default {
  props: {
    value: {
      type: Object,
      default: () => defaultAudienceState(),
    },
    showError: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      localState: defaultAudienceState(),
    };
  },
  computed: {
    ...mapGetters({
      audienceList: 'labels/getLabels',
    }),
    labelsValid() {
      return this.localState.selectedLabels.length > 0;
    },
    isComplete() {
      if (this.localState.source === AUDIENCE_SOURCES.SPREADSHEET) {
        return this.localState.contactList.length > 0;
      }
      return this.localState.selectedLabels.length > 0;
    },
  },
  watch: {
    value: {
      immediate: true,
      deep: true,
      handler(newValue) {
        this.localState = {
          ...defaultAudienceState(),
          ...(newValue || {}),
        };
      },
    },
  },
  methods: {
    emitChange() {
      this.$emit('input', { ...this.localState });
    },
    hasSourceData(source) {
      if (source === AUDIENCE_SOURCES.LABELS) {
        return this.localState.selectedLabels.length > 0;
      }
      return this.localState.contactList.length > 0;
    },
    switchSource(source) {
      if (this.localState.source === source) return;

      if (this.hasSourceData(this.localState.source)) {
        const confirmed = window.confirm(
          this.$t('CAMPAIGN.ADD.FORM.AUDIENCE_SOURCE.SWITCH_CONFIRM')
        );
        if (!confirmed) return;
      }

      this.localState.source = source;
      this.localState.selectedLabels = [];
      this.localState.contactList = [];
      this.localState.contactCount = 0;
      this.localState.fileUploadError = '';
      this.localState.validationMessages = [];
      this.localState.hasMoreInvalidNumbers = false;
      this.localState.totalInvalidNumbers = 0;
      if (this.$refs.fileInput) {
        this.$refs.fileInput.value = '';
      }
      this.emitChange();
    },
    downloadTemplate() {
      const worksheet = XLSX.utils.aoa_to_sheet([
        ['numeros', 'nome', 'variavel'],
        ['5511999999999', 'João Silva', 'PromoVerão'],
      ]);
      const workbook = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(workbook, worksheet, 'Contatos');
      XLSX.writeFile(workbook, 'modelo-campanha.xlsx');
    },
    handleFileUpload(event) {
      const file = event.target.files[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = e => {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        const firstSheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[firstSheetName];
        const jsonData = XLSX.utils.sheet_to_json(worksheet);

        const possibleNumberColumns = [
          'numeros',
          'numero',
          'Número',
          'número',
          'nUmeros',
          'telefone',
          'phone',
        ];
        const possibleNameColumns = ['nome', 'Nome', 'Nomes'];
        const possibleVariableColumns = [
          'variavel',
          'variável',
          'Variavel',
          'Variável',
        ];

        const findColumn = (possibleColumns, row) =>
          possibleColumns.find(column => column in row);

        const numberColumn = jsonData.length
          ? findColumn(possibleNumberColumns, jsonData[0])
          : null;
        const nameColumn = jsonData.length
          ? findColumn(possibleNameColumns, jsonData[0])
          : null;
        const variableColumn = jsonData.length
          ? findColumn(possibleVariableColumns, jsonData[0])
          : null;

        if (jsonData.length > 0 && numberColumn) {
          const contacts = jsonData
            .map(row => ({
              numero: row[numberColumn],
              nome: nameColumn ? row[nameColumn] || '' : '',
              variavel: variableColumn ? row[variableColumn] || '' : '',
            }))
            .filter(contact => contact.numero);

          const validationResult = validatePhoneList(contacts);

          if (validationResult.hasErrors) {
            if (validationResult.totalInvalid > 50) {
              this.localState.fileUploadError = this.$t(
                'CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_TOO_MANY_INVALID',
                { count: validationResult.totalInvalid }
              );
            } else {
              this.localState.fileUploadError = this.$t(
                'CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_INVALID_NUMBERS',
                {
                  count: validationResult.totalInvalid,
                  total: contacts.length,
                }
              );
            }

            this.localState.validationMessages =
              validationResult.limitedInvalidNumbers.map(
                contact =>
                  `${contact.numero}: ${this.$t(contact.messageKey)}`
              );
            this.localState.hasMoreInvalidNumbers =
              validationResult.hasMoreInvalid;
            this.localState.totalInvalidNumbers =
              validationResult.totalInvalid;
            this.localState.contactList = [];
            this.localState.contactCount = 0;
          } else {
            this.localState.contactList = validationResult.validNumbers;
            this.localState.contactCount = this.localState.contactList.length;
            this.localState.fileUploadError = '';
            this.localState.validationMessages = [];
            this.localState.hasMoreInvalidNumbers = false;
            this.localState.totalInvalidNumbers = 0;
          }
        } else {
          this.localState.fileUploadError = this.$t(
            'CAMPAIGN.ADD.FORM.CONTACT_LIST.ERROR_NO_COLUMN'
          );
          this.localState.contactList = [];
          this.localState.contactCount = 0;
          this.localState.validationMessages = [];
          this.localState.hasMoreInvalidNumbers = false;
          this.localState.totalInvalidNumbers = 0;
        }

        this.emitChange();
      };

      reader.readAsArrayBuffer(file);
    },
    removeContactList() {
      this.localState.contactList = [];
      this.localState.contactCount = 0;
      this.localState.fileUploadError = '';
      this.localState.validationMessages = [];
      if (this.$refs.fileInput) {
        this.$refs.fileInput.value = '';
      }
      this.emitChange();
    },
  },
};
</script>

<style lang="scss" scoped>
.campaign-audience-selector {
  @apply mb-4;
}

.audience-label {
  @apply text-sm font-medium text-slate-800 dark:text-slate-100 mb-2;
}

.audience-tabs {
  @apply flex gap-2 mb-3;
}

.audience-tab {
  @apply px-3 py-1.5 text-xs font-medium rounded-lg transition-colors duration-150;
  @apply bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300;
  @apply hover:bg-slate-200 dark:hover:bg-slate-600;

  &--active {
    @apply bg-woot-500 text-white hover:bg-woot-500;
  }
}

.audience-panel {
  @apply mt-1;
}

.audience-hint {
  @apply text-xs text-slate-500 dark:text-slate-400 mb-2;
}

.spreadsheet-panel {
  @apply mt-1;

  .error-message {
    @apply text-red-500 mt-2 text-xs;
  }

  .contact-list-info {
    @apply flex justify-between items-center mt-2;

    .contact-count {
      @apply text-xs text-slate-600 dark:text-slate-300;
    }

    .delete-button {
      @apply bg-transparent border-0 cursor-pointer text-slate-400 hover:text-red-500 p-0.5;
    }
  }
}

.spreadsheet-toolbar {
  @apply flex items-center justify-between gap-3;
}

.file-picker {
  @apply inline-flex cursor-pointer;
}

.file-picker-input {
  @apply sr-only;
}

.file-picker-label {
  @apply inline-flex items-center px-3 py-1.5 text-xs font-medium rounded-lg;
  @apply bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200;
  @apply hover:bg-slate-200 dark:hover:bg-slate-600 transition-colors duration-150;
}

.audience-count {
  @apply text-xs text-slate-500 dark:text-slate-400 mt-1 block;
}

.template-download-link {
  @apply text-xs text-slate-500 dark:text-slate-400 hover:text-woot-500;
  @apply underline underline-offset-2 bg-transparent border-0 p-0 cursor-pointer shrink-0;
}

.validation-messages {
  @apply mt-3 p-2 border-l-4 border-red-500 rounded;

  .validation-title {
    @apply font-medium text-sm text-red-600 dark:text-red-400 mb-1;
  }

  .validation-list {
    @apply list-none p-0 m-0 max-h-36 overflow-y-auto;
  }

  .validation-item {
    @apply py-1 text-xs text-red-600 dark:text-red-400 border-b border-slate-100 dark:border-slate-700;
  }

  .more-invalid-note {
    @apply mt-2 text-xs italic text-slate-500;
  }
}
</style>
