<template>
  <div class="relative template-variable-input">
    <variable-list
      v-if="showVariables"
      :search-key="variableSearchTerm"
      @click="insertVariable"
    />
    <woot-input
      :value="value"
      type="text"
      class="variable-input"
      :styles="{ marginBottom: 0 }"
      :placeholder="placeholder"
      @input="onInput"
      @keydown.native="onKeydown"
    />
  </div>
</template>

<script>
import VariableList from '../VariableList.vue';

export default {
  components: { VariableList },
  props: {
    value: {
      type: String,
      default: '',
    },
    placeholder: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      showVariables: false,
      variableSearchTerm: '',
    };
  },
  methods: {
    onInput(value) {
      this.$emit('input', value);
      this.updateVariableMenu(value);
    },
    onKeydown(event) {
      if (event.key === 'Escape') {
        this.showVariables = false;
      }
    },
    updateVariableMenu(value) {
      const openBraceIndex = value.lastIndexOf('{');
      if (openBraceIndex === -1) {
        this.showVariables = false;
        return;
      }

      const textAfterBrace = value.slice(openBraceIndex);
      if (textAfterBrace.startsWith('{{') && !textAfterBrace.includes('}}')) {
        this.showVariables = true;
        this.variableSearchTerm = textAfterBrace
          .replace(/^\{\{/, '')
          .replace(/\{$/, '');
        return;
      }

      if (value.endsWith('{')) {
        this.showVariables = true;
        this.variableSearchTerm = '';
        return;
      }

      this.showVariables = false;
    },
    insertVariable(variableKey) {
      const currentValue = this.value || '';
      const openBraceIndex = currentValue.lastIndexOf('{');
      const prefix =
        openBraceIndex >= 0 ? currentValue.slice(0, openBraceIndex) : currentValue;
      const newValue = `${prefix}{{${variableKey}}}`;
      this.$emit('input', newValue);
      this.showVariables = false;
      this.variableSearchTerm = '';
    },
  },
};
</script>

<style scoped lang="scss">
.template-variable-input {
  @apply flex-1 ml-2.5;

  .variable-input {
    @apply w-full;
  }
}
</style>
