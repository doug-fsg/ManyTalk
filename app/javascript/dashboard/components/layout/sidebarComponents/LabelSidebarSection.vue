<template>
  <div>
    <template v-if="isGrouped">
      <div
        v-for="section in sections"
        :key="section.id"
        class="mb-1"
      >
        <button
          type="button"
          class="flex items-center justify-between w-full h-7 px-2 my-1 rounded-lg text-sm font-medium text-slate-700 dark:text-slate-100 hover:bg-slate-25 dark:hover:bg-slate-800 transition-all duration-200 ease-smooth"
          :aria-expanded="isExpanded(section.id)"
          :aria-controls="`label-group-${section.id}`"
          @click="toggleSection(section.id)"
        >
          <span class="flex items-center min-w-0">
            <fluent-icon
              :icon="isExpanded(section.id) ? 'chevron-down' : 'chevron-right'"
              size="12"
              class="mr-1.5 rtl:mr-0 rtl:ml-1.5 flex-shrink-0"
            />
            <span class="truncate">{{ sectionTitle(section) }}</span>
          </span>
          <span
            class="bg-slate-50 dark:bg-slate-700 rounded-full min-w-[18px] justify-center items-center flex text-xxs font-medium mx-1 py-0 px-1 text-slate-700 dark:text-slate-50"
          >
            {{ section.labels.length }}
          </span>
        </button>
        <ul
          v-show="isExpanded(section.id)"
          :id="`label-group-${section.id}`"
          class="mb-0 ml-0 list-none max-h-44 overflow-y-auto"
        >
          <secondary-child-nav-item
            v-for="label in section.labels"
            :key="label.id"
            :to="pathFor(label)"
            :label="label.title"
            :label-color="label.color"
            :should-truncate="true"
          />
        </ul>
      </div>
    </template>
    <ul v-else class="mb-0 ml-0 list-none">
      <secondary-child-nav-item
        v-for="label in labels"
        :key="label.id"
        :to="pathFor(label)"
        :label="label.title"
        :label-color="label.color"
        :should-truncate="true"
      />
    </ul>
  </div>
</template>

<script>
import SecondaryChildNavItem from './SecondaryChildNavItem.vue';

export default {
  components: {
    SecondaryChildNavItem,
  },
  props: {
    labels: {
      type: Array,
      default: () => [],
    },
    sections: {
      type: Array,
      default: () => [],
    },
    mode: {
      type: String,
      default: 'flat',
    },
    pathBuilder: {
      type: Function,
      required: true,
    },
  },
  data() {
    return {
      expandedIds: {},
    };
  },
  computed: {
    isGrouped() {
      return this.mode === 'grouped';
    },
  },
  watch: {
    '$route.path': {
      immediate: true,
      handler() {
        this.expandActiveSection();
      },
    },
    sections: {
      immediate: true,
      handler() {
        this.expandActiveSection();
      },
    },
  },
  methods: {
    sectionTitle(section) {
      return section.name || this.$t('LABEL_MGMT.GROUP.NONE');
    },
    pathFor(label) {
      return this.pathBuilder(label);
    },
    isExpanded(sectionId) {
      return !!this.expandedIds[sectionId];
    },
    toggleSection(sectionId) {
      this.$set(this.expandedIds, sectionId, !this.expandedIds[sectionId]);
    },
    expandActiveSection() {
      if (!this.isGrouped) {
        return;
      }
      const activeSection = this.sections.find(section =>
        section.labels.some(label => this.pathFor(label) === this.$route.path)
      );
      if (activeSection) {
        this.$set(this.expandedIds, activeSection.id, true);
      }
    },
  },
};
</script>
