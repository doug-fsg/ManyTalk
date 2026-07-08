<template>
  <div class="relative inline-flex">
    <woot-button
      ref="mergeTrigger"
      v-tooltip="$t('CONTACT_PANEL.MERGE')"
      :title="$t('CONTACT_PANEL.MERGE')"
      icon="merge"
      variant="smooth"
      size="small"
      color-scheme="secondary"
      :disabled="disabled"
      @click="toggleDropdown"
    />
    <div
      v-if="showDropdown"
      v-on-clickaway="closeDropdown"
      :style="dropdownStyle"
      class="dropdown-pane dropdown-pane--open merge-actions-dropdown"
    >
      <woot-dropdown-menu class="mb-0">
        <woot-dropdown-item>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="person"
            class="w-full !justify-start whitespace-nowrap"
            @click="onMergeContact"
          >
            {{ $t('CONTACT_PANEL.MERGE_CONTACT') }}
          </woot-button>
        </woot-dropdown-item>
        <woot-dropdown-item v-if="canMergeConversation">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="chat"
            class="w-full !justify-start whitespace-nowrap"
            @click="onMergeConversation"
          >
            {{ $t('CONTACT_PANEL.MERGE_CONVERSATION') }}
          </woot-button>
        </woot-dropdown-item>
      </woot-dropdown-menu>
    </div>
  </div>
</template>

<script>
import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';

const MENU_WIDTH = 208;
const VIEWPORT_PADDING = 8;

export default {
  components: {
    WootDropdownItem,
    WootDropdownMenu,
  },
  props: {
    disabled: {
      type: Boolean,
      default: false,
    },
    canMergeConversation: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      showDropdown: false,
      dropdownStyle: {},
    };
  },
  mounted() {
    window.addEventListener('scroll', this.handleScroll, true);
    window.addEventListener('resize', this.handleResize);
  },
  beforeDestroy() {
    window.removeEventListener('scroll', this.handleScroll, true);
    window.removeEventListener('resize', this.handleResize);
  },
  methods: {
    toggleDropdown() {
      if (this.showDropdown) {
        this.closeDropdown();
        return;
      }

      this.showDropdown = true;
      this.$nextTick(this.updateDropdownPosition);
    },
    updateDropdownPosition() {
      const trigger = this.$refs.mergeTrigger?.$el || this.$refs.mergeTrigger;
      if (!trigger) return;

      const rect = trigger.getBoundingClientRect();
      let left = rect.left;

      if (left + MENU_WIDTH > window.innerWidth - VIEWPORT_PADDING) {
        left = rect.right - MENU_WIDTH;
      }

      left = Math.max(
        VIEWPORT_PADDING,
        Math.min(left, window.innerWidth - MENU_WIDTH - VIEWPORT_PADDING)
      );

      this.dropdownStyle = {
        position: 'fixed',
        top: `${rect.bottom + 4}px`,
        left: `${left}px`,
        minWidth: '13rem',
        zIndex: 9999,
      };
    },
    handleScroll() {
      if (this.showDropdown) {
        this.closeDropdown();
      }
    },
    handleResize() {
      if (this.showDropdown) {
        this.updateDropdownPosition();
      }
    },
    closeDropdown() {
      this.showDropdown = false;
      this.dropdownStyle = {};
    },
    onMergeContact() {
      this.closeDropdown();
      this.$emit('merge-contact');
    },
    onMergeConversation() {
      this.closeDropdown();
      this.$emit('merge-conversation');
    },
  },
};
</script>

<style scoped lang="scss">
.merge-actions-dropdown {
  @apply p-1;
}
</style>
