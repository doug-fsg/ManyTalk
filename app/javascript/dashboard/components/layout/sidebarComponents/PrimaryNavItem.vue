<template>
  <router-link v-slot="{ href, isActive, navigate }" :to="to" custom>
    <a
      v-tooltip.right="tooltipText"
      :href="href"
      :aria-label="accessibleLabel"
      class="group text-white/75 dark:text-slate-300 w-10 h-10 my-1 flex items-center justify-center rounded-xl cursor-pointer relative transition-all duration-200 ease-out hover:bg-white/15 hover:text-white dark:hover:bg-white/10 dark:hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70 focus-visible:ring-offset-2 focus-visible:ring-offset-woot-600 dark:focus-visible:ring-offset-woot-800 motion-reduce:transition-none"
      :class="{
        'bg-white text-woot-600 shadow-sm hover:bg-white hover:text-woot-600 dark:bg-slate-100 dark:text-woot-600 dark:hover:bg-slate-100 dark:shadow-md dark:shadow-woot-500/15':
          isActive || isChildMenuActive,
      }"
      :rel="openInNewPage ? 'noopener noreferrer nofollow' : undefined"
      :target="openInNewPage ? '_blank' : undefined"
      @click="navigate"
    >
      <fluent-icon
        :icon="icon"
        class="transition-all duration-200 ease-out motion-reduce:transition-none motion-reduce:transform-none"
        :class="
          isActive || isChildMenuActive
            ? 'text-woot-600 scale-100 opacity-100'
            : 'opacity-80 group-hover:opacity-100 group-hover:scale-110 group-hover:text-white dark:group-hover:text-white'
        "
      />
      <span class="sr-only">{{ accessibleLabel }}</span>
      <span
        v-if="beta"
        class="absolute -top-0.5 -right-0.5 px-1 py-0.5 text-[9px] font-semibold leading-none text-green-600 dark:text-green-400 bg-green-100 dark:bg-green-900/40 border border-green-400 dark:border-green-600 rounded"
      >
        {{ $t('SIDEBAR.BETA') }}
      </span>
      <span
        v-else-if="count"
        class="absolute -top-1 -right-1 min-w-[1rem] px-1 text-[10px] font-semibold leading-4 text-slate-900 bg-yellow-400 rounded-full text-center"
      >
        {{ count }}
      </span>
    </a>
  </router-link>
</template>
<script>
export default {
  props: {
    to: {
      type: String,
      default: '',
    },
    name: {
      type: String,
      default: '',
    },
    icon: {
      type: String,
      default: '',
    },
    count: {
      type: String,
      default: '',
    },
    isChildMenuActive: {
      type: Boolean,
      default: false,
    },
    openInNewPage: {
      type: Boolean,
      default: false,
    },
    beta: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    accessibleLabel() {
      return this.$t(`SIDEBAR.${this.name}`);
    },
    tooltipText() {
      if (this.beta) {
        return `${this.accessibleLabel} (${this.$t('SIDEBAR.BETA')})`;
      }
      return this.accessibleLabel;
    },
  },
};
</script>
