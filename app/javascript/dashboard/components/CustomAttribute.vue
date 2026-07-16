<template>
  <div class="py-3 px-4">
    <div class="flex items-center mb-1">
      <h4 class="text-sm flex items-center m-0 w-full error">
        <div v-if="isAttributeTypeCheckbox" class="flex items-center">
          <input
            v-model="editedValue"
            class="!my-0 mr-2 ml-0"
            type="checkbox"
            @change="onUpdate"
          />
        </div>
        <div class="flex items-center justify-between w-full">
          <span
            class="w-full inline-flex gap-1.5 items-start font-medium whitespace-nowrap text-sm mb-0"
            :class="
              $v.editedValue.$error
                ? 'text-red-400 dark:text-red-500'
                : 'text-slate-800 dark:text-slate-100'
            "
          >
            {{ label }}
            <helper-text-popup
              v-if="description"
              :message="description"
              class="mt-0.5"
            />
          </span>
          <woot-button
            v-if="showActions && value"
            v-tooltip.left="$t('CUSTOM_ATTRIBUTES.ACTIONS.DELETE')"
            variant="link"
            size="medium"
            color-scheme="secondary"
            icon="delete"
            class-names="flex justify-end w-4"
            @click="onDelete"
          />
        </div>
      </h4>
    </div>
    <div v-if="notAttributeTypeCheckboxAndList">
      <div v-if="isEditing" v-on-clickaway="onClickAway">
        <div
          class="mb-2 w-full flex"
          :class="isAttributeTypeTextarea ? 'items-start' : 'items-center'"
        >
          <textarea
            v-if="isAttributeTypeTextarea"
            ref="inputfield"
            v-model="editedValue"
            rows="4"
            class="ltr:!rounded-r-none rtl:!rounded-l-none !mb-0 !text-sm min-h-[7.5rem] resize-y leading-relaxed py-2"
            autofocus="true"
            :class="{ error: $v.editedValue.$error }"
            @blur="$v.editedValue.$touch"
            @keydown.ctrl.enter="onUpdate"
            @keydown.meta.enter="onUpdate"
          />
          <input
            v-else
            ref="inputfield"
            v-model="editedValue"
            :type="inputType"
            class="!h-8 ltr:!rounded-r-none rtl:!rounded-l-none !mb-0 !text-sm"
            autofocus="true"
            :class="{ error: $v.editedValue.$error }"
            @blur="$v.editedValue.$touch"
            @keyup.enter="onUpdate"
          />
          <div>
            <woot-button
              size="small"
              icon="checkmark"
              class="rounded-l-none rtl:rounded-r-none"
              @click="onUpdate"
            />
          </div>
        </div>
        <span
          v-if="shouldShowErrorMessage"
          class="text-red-400 dark:text-red-500 text-sm block font-normal -mt-px w-full"
        >
          {{ errorMessage }}
        </span>
      </div>
      <div
        v-show="!isEditing"
        class="flex group"
        :class="{ 'is-editable': showActions }"
      >
        <a
          v-if="isAttributeTypeLink"
          :href="hrefURL"
          target="_blank"
          rel="noopener noreferrer"
          class="group-hover:bg-slate-50 group-hover:dark:bg-slate-700 inline-block rounded-sm mb-0 break-all py-0.5 px-1"
        >
          {{ urlValue }}
        </a>
        <p
          v-else
          class="group-hover:bg-slate-50 group-hover:dark:bg-slate-700 inline-block rounded-sm mb-0 break-all py-0.5 px-1"
          :class="{ 'whitespace-pre-wrap': isAttributeTypeTextarea }"
        >
          {{ displayValue || '---' }}
        </p>
        <div class="flex max-w-[2rem] gap-1 ml-1 rtl:mr-1 rtl:ml-0">
          <woot-button
            v-if="showActions && value"
            v-tooltip="$t('CUSTOM_ATTRIBUTES.ACTIONS.COPY')"
            variant="link"
            size="small"
            color-scheme="secondary"
            icon="clipboard"
            class-names="hidden group-hover:flex !w-6 flex-shrink-0"
            @click="onCopy"
          />
          <woot-button
            v-if="showActions"
            v-tooltip.right="$t('CUSTOM_ATTRIBUTES.ACTIONS.EDIT')"
            variant="link"
            size="small"
            color-scheme="secondary"
            icon="edit"
            class-names="hidden group-hover:flex !w-6 flex-shrink-0"
            @click="onEdit"
          />
        </div>
      </div>
    </div>
    <div v-if="isAttributeTypeList">
      <multiselect-dropdown
        :options="listOptions"
        :selected-item="selectedItem"
        :has-thumbnail="false"
        :multiselector-placeholder="
          $t('CUSTOM_ATTRIBUTES.FORM.ATTRIBUTE_TYPE.LIST.PLACEHOLDER')
        "
        :no-search-result="
          $t('CUSTOM_ATTRIBUTES.FORM.ATTRIBUTE_TYPE.LIST.NO_RESULT')
        "
        :input-placeholder="
          $t(
            'CUSTOM_ATTRIBUTES.FORM.ATTRIBUTE_TYPE.LIST.SEARCH_INPUT_PLACEHOLDER'
          )
        "
        @click="onUpdateListValue"
      />
    </div>
    <div v-if="isAttributeTypeFile">
      <custom-attribute-file-upload
        :value="value || []"
        :contact-id="contactId"
        :attribute-key="attributeKey"
        :max-files="5"
        @update="onFileUpdate"
      />
    </div>
  </div>
</template>

<script>
import { format, parseISO } from 'date-fns';
import { required, url } from 'vuelidate/lib/validators';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import HelperTextPopup from 'dashboard/components/ui/HelperTextPopup.vue';
import CustomAttributeFileUpload from 'dashboard/components/CustomAttributeFileUpload.vue';
import { isValidURL } from '../helper/URLHelper';
import customAttributeMixin from '../mixins/customAttributeMixin';

const DATE_FORMAT = 'yyyy-MM-dd';

export default {
  components: {
    MultiselectDropdown,
    HelperTextPopup,
    CustomAttributeFileUpload,
  },
  mixins: [customAttributeMixin],
  props: {
    label: { type: String, required: true },
    description: { type: String, default: '' },
    values: { type: Array, default: () => [] },
    value: { type: [String, Number, Boolean], default: '' },
    showActions: { type: Boolean, default: false },
    attributeType: { type: String, default: 'text' },
    attributeRegex: {
      type: String,
      default: null,
    },
    regexCue: { type: String, default: null },
    regexEnabled: { type: Boolean, default: false },
    attributeKey: { type: String, required: true },
    contactId: { type: Number, default: null },
  },
  data() {
    return {
      isEditing: false,
      editedValue: null,
    };
  },
  computed: {
    displayValue() {
      if (this.isAttributeTypeDate) {
        return this.value
          ? new Date(this.value || new Date()).toLocaleDateString()
          : '';
      }
      if (this.isAttributeTypeCheckbox) {
        return this.value === 'false' ? false : this.value;
      }
      // Para atributos do tipo list, converter stage_id para nome legível se necessário
      if (this.isAttributeTypeList && this.value && this.values.length > 0) {
        return this.getDisplayNameFromValue(this.value) || this.value;
      }
      return this.value;
    },
    formattedValue() {
      return this.isAttributeTypeDate
        ? format(this.value ? new Date(this.value) : new Date(), DATE_FORMAT)
        : this.value;
    },
    listOptions() {
      return this.values.map((value, index) => {
        const name = this.getValueName(value);
        return {
          id: index + 1,
          name: name,
        };
      });
    },
    selectedItem() {
      const valueName = this.getDisplayNameFromValue(this.editedValue) || this.editedValue;
      const index = this.values.findIndex(v => {
        const vName = this.getValueName(v);
        return vName === valueName || vName === this.editedValue;
      });
      const id = index >= 0 ? index + 1 : 1;
      return { id, name: valueName };
    },
    isAttributeTypeCheckbox() {
      return this.attributeType === 'checkbox';
    },
    isAttributeTypeList() {
      return this.attributeType === 'list';
    },
    isAttributeTypeLink() {
      return this.attributeType === 'link';
    },
    isAttributeTypeDate() {
      return this.attributeType === 'date';
    },
    isAttributeTypeFile() {
      return this.attributeType === 'file';
    },
    isAttributeTypeTextarea() {
      return this.attributeType === 'textarea';
    },
    urlValue() {
      return isValidURL(this.value) ? this.value : '---';
    },
    hrefURL() {
      return isValidURL(this.value) ? this.value : '';
    },
    notAttributeTypeCheckboxAndList() {
      return !this.isAttributeTypeCheckbox && !this.isAttributeTypeList && !this.isAttributeTypeFile;
    },
    inputType() {
      if (this.isAttributeTypeLink) return 'url';
      if (this.isAttributeTypeTextarea) return 'text';
      if (this.isAttributeTypeDate) return 'date';
      return 'text';
    },
    shouldShowErrorMessage() {
      return this.$v.editedValue.$error;
    },
    errorMessage() {
      if (this.$v.editedValue.url) {
        return this.$t('CUSTOM_ATTRIBUTES.VALIDATIONS.INVALID_URL');
      }
      if (!this.$v.editedValue.regexValidation) {
        return this.regexCue
          ? this.regexCue
          : this.$t('CUSTOM_ATTRIBUTES.VALIDATIONS.INVALID_INPUT');
      }
      return this.$t('CUSTOM_ATTRIBUTES.VALIDATIONS.REQUIRED');
    },
  },
  watch: {
    value() {
      this.isEditing = false;
      this.editedValue = this.formattedValue;
    },
    contactId() {
      // Fix to solve validation not resetting when contactId changes in contact page
      this.$v.$reset();
    },
  },

  validations() {
    if (this.isAttributeTypeLink) {
      return {
        editedValue: { required, url },
      };
    }
    return {
      editedValue: {
        required,
        regexValidation: value => {
          return !(
            this.attributeRegex &&
            !this.getRegexp(this.attributeRegex).test(value)
          );
        },
      },
    };
  },
  mounted() {
    this.editedValue = this.formattedValue;
    this.$emitter.on(BUS_EVENTS.FOCUS_CUSTOM_ATTRIBUTE, this.onFocusAttribute);
  },
  destroyed() {
    this.$emitter.off(BUS_EVENTS.FOCUS_CUSTOM_ATTRIBUTE, this.onFocusAttribute);
  },
  methods: {
    // Extrair nome de um valor (suporta objeto {name, color} ou string)
    getValueName(value) {
      if (typeof value === 'object' && value !== null) {
        return value.name || value.value || String(value);
      }
      return String(value);
    },
    // Converter stage_id para nome legível buscando nos values
    getDisplayNameFromValue(stageId) {
      if (!stageId || !this.values || this.values.length === 0) {
        return null;
      }
      const stage = this.values.find(v => {
        const vName = this.getValueName(v);
        return vName === stageId || v === stageId;
      });
      return stage ? this.getValueName(stage) : null;
    },
    onFocusAttribute(focusAttributeKey) {
      if (this.attributeKey === focusAttributeKey) {
        this.onEdit();
      }
    },
    focusInput() {
      if (this.$refs.inputfield) {
        this.$refs.inputfield.focus();
      }
    },
    onClickAway() {
      this.$v.$reset();
      this.isEditing = false;
    },
    onEdit() {
      this.isEditing = true;
      this.$nextTick(() => {
        this.focusInput();
      });
    },
    onUpdateListValue(value) {
      if (value) {
        this.editedValue = value.name;
        this.onUpdate();
      }
    },
    onUpdate() {
      const updatedValue =
        this.attributeType === 'date'
          ? parseISO(this.editedValue)
          : this.editedValue;
      this.$v.$touch();
      if (this.$v.$invalid) {
        return;
      }
      this.isEditing = false;
      this.$emit('update', this.attributeKey, updatedValue);
    },
    onFileUpdate(attributeKey, value) {
      // For file attributes, directly emit the update without validation
      this.$emit('update', attributeKey, value);
    },
    onDelete() {
      this.isEditing = false;
      this.$v.$reset();
      this.$emit('delete', this.attributeKey);
    },
    onCopy() {
      this.$emit('copy', this.value);
    },
  },
};
</script>

<style lang="scss" scoped>
::v-deep {
  .selector-wrap {
    @apply m-0 top-1;
    .selector-name {
      @apply ml-0;
    }
  }
  .name {
    @apply ml-0;
  }
}
</style>
