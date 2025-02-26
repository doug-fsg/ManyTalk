/* eslint-disable */

<template>
  <div class="h-auto overflow-auto flex flex-col">
    <woot-modal-header
      :header-title="pageTitle"
      :header-content="$t('CAMPAIGN.ADD.DESC')"
    />
    <form class="flex flex-col w-full" @submit.prevent="saveCampaign">
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
          <label>{{ $t('CAMPAIGN.ADD.FORM.MESSAGE.LABEL') }}</label>
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

        <label :class="{ error: $v.selectedInbox.$error }">
          {{ $t('CAMPAIGN.ADD.FORM.INBOX.LABEL') }}
          <select v-model="selectedInbox" @change="onChangeInbox">
            <option v-for="item in inboxes" :key="item.id" :value="item.id">
              {{ item.name }}
            </option>
          </select>
          <span v-if="$v.selectedInbox.$error" class="message">
            {{ $t('CAMPAIGN.ADD.FORM.INBOX.ERROR') }}
          </span>
        </label>

        <label v-if="isOneOffType" class="file-upload-section">
          <label>
            {{ $t('CAMPAIGN.ADD.FORM.CONTACT_LIST.LABEL') }}
            <input type="file" accept=".xlsx, .xls, .csv" @change="handleFileUpload" />
          </label>
          <p v-if="fileUploadError" class="error-message">{{ fileUploadError }}</p>
          <div v-if="contactCount" class="contact-list-info">
            <p class="contact-count">
              {{ $t('CAMPAIGN.ADD.FORM.CONTACT_LIST.CONTACT_COUNT', { count: contactCount }) }}
            </p>
            <button class="delete-button" @click="removeContactList">🗑️</button>
          </div>
        </label>
      </div>

      <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
        <woot-button :is-loading="uiFlags.isCreating">
          {{ isEditing ? $t('CAMPAIGN.EDIT.UPDATE_BUTTON_TEXT') : $t('CAMPAIGN.ADD.CREATE_BUTTON_TEXT') }}
        </woot-button>
        <woot-button variant="clear" @click.prevent="onClose">
          {{ $t('CAMPAIGN.ADD.CANCEL_BUTTON_TEXT') }}
        </woot-button>
      </div>
    </form>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { required } from 'vuelidate/lib/validators';
import { validationMixin } from 'vuelidate';
import { useAlert } from 'dashboard/composables';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

export default {
  components: { WootMessageEditor },
  mixins: [validationMixin],
  props: {
    selectedCampaign: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      title: '',
      message: '',
      selectedInbox: null,
      contactList: [],
      fileUploadError: '',
      contactCount: 0,
    };
  },
  validations: {
    title: { required },
    message: { required },
    selectedInbox: { required },
  },
  computed: {
    ...mapGetters({ uiFlags: 'campaigns/getUIFlags' }),
    isEditing() {
      return !!this.selectedCampaign.id;
    },
    pageTitle() {
      return this.isEditing
        ? `Editar Campanha: ${this.selectedCampaign.title}`
        : this.$t('CAMPAIGN.ADD.TITLE');
    },
  },
  mounted() {
    if (this.isEditing) {
      this.setFormValuesForEdit();
    }
  },
  methods: {
    onClose() {
      this.$emit('on-close');
    },
    saveCampaign() {
      this.$v.$touch();
      if (this.$v.$invalid) return;

      const campaignDetails = {
        title: this.title,
        message: this.message,
        inbox_id: this.selectedInbox,
        contact_list: this.contactList,
      };

      if (this.isEditing) {
        this.$store.dispatch('campaigns/update', {
          id: this.selectedCampaign.id,
          ...campaignDetails,
        })
        .then(() => useAlert(this.$t('CAMPAIGN.EDIT.API.SUCCESS_MESSAGE')))
        .catch(() => useAlert(this.$t('CAMPAIGN.EDIT.API.ERROR_MESSAGE')));
      } else {
        this.$store.dispatch('campaigns/create', campaignDetails)
        .then(() => useAlert(this.$t('CAMPAIGN.ADD.API.SUCCESS_MESSAGE')))
        .catch(() => useAlert(this.$t('CAMPAIGN.ADD.API.ERROR_MESSAGE')));
      }

      this.onClose();
    },
    setFormValuesForEdit() {
      if (!this.selectedCampaign) return;

      this.title = this.selectedCampaign.title || '';
      this.message = this.selectedCampaign.message || '';
      this.selectedInbox = this.selectedCampaign.inbox?.id || null;
      this.scheduledAt = this.selectedCampaign.scheduled_at || null;
      this.contactList = this.selectedCampaign.contact_list || [];
      this.contactCount = this.contactList.length;
    },
    removeContactList() {
      this.contactList = [];
      this.contactCount = 0;
    },
    handleFileUpload(event) {
      const file = event.target.files[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = (e) => {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        const sheet = workbook.Sheets[workbook.SheetNames[0]];
        const jsonData = XLSX.utils.sheet_to_json(sheet);

        this.contactList = jsonData.map(row => ({
          numero: row['numero'] || '',
          nome: row['nome'] || '',
        })).filter(contact => contact.numero);

        this.contactCount = this.contactList.length;
      };

      reader.readAsArrayBuffer(file);
    },
  },
};
</script>

<style scoped>
.file-upload-section {
  margin-bottom: 1rem;
}
.contact-list-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
