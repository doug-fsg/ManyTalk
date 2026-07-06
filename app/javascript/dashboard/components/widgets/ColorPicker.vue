<template>
  <div class="colorpicker" :class="{ 'colorpicker--open': isPickerOpen }">
    <div
      ref="swatch"
      class="colorpicker--selected"
      :style="`background-color: ${value}`"
      @click.prevent="toggleColorPicker"
    />
    <chrome
      v-if="isPickerOpen"
      v-on-clickaway="closeTogglePicker"
      :disable-alpha="true"
      :value="value"
      class="colorpicker--chrome"
      :style="pickerStyle"
      @input="updateColor"
    />
  </div>
</template>

<script>
import { Chrome } from 'vue-color';

export default {
  components: {
    Chrome,
  },
  props: {
    value: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      isPickerOpen: false,
      pickerStyle: {},
    };
  },
  methods: {
    closeTogglePicker() {
      if (this.isPickerOpen) {
        this.isPickerOpen = false;
      }
    },
    toggleColorPicker() {
      this.isPickerOpen = !this.isPickerOpen;
      if (this.isPickerOpen) {
        this.$nextTick(() => this.positionPicker());
      }
    },
    positionPicker() {
      const swatch = this.$refs.swatch;
      if (!swatch) return;

      const rect = swatch.getBoundingClientRect();
      const panelWidth = 225;
      const panelHeight = 242;
      const gap = 8;

      let left = rect.left;
      let top = rect.bottom + gap;

      if (left + panelWidth > window.innerWidth - 8) {
        left = Math.max(8, window.innerWidth - panelWidth - 8);
      }
      if (top + panelHeight > window.innerHeight - 8) {
        top = Math.max(8, rect.top - panelHeight - gap);
      }

      this.pickerStyle = {
        position: 'fixed',
        top: `${top}px`,
        left: `${left}px`,
        zIndex: 100000,
      };
    },
    updateColor(e) {
      this.$emit('input', e.hex);
    },
  },
};
</script>

<style scoped lang="scss">
.colorpicker {
  position: relative;
  display: inline-flex;
  vertical-align: middle;
}

.colorpicker--open {
  z-index: 100000;
}

.colorpicker--selected {
  @apply border border-solid border-slate-50 dark:border-slate-600 rounded-lg cursor-pointer h-8 w-8 transition-all duration-200 ease-smooth hover:shadow-soft;
}

.colorpicker--chrome.vc-chrome {
  @apply shadow-soft-xl border border-solid border-slate-75 dark:border-slate-600 rounded-xl animate-scale-in;

  ::v-deep {
    input {
      @apply bg-white dark:bg-white;
    }
  }
}
</style>
