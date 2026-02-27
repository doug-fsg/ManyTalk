<template>
  <router-link v-slot="{ href, isActive, navigate }" :to="to" custom>
    <a
      v-tooltip.right="tooltipText"
      :href="href"
      class="text-slate-50 dark:text-slate-100 w-10 h-10 my-2 flex items-center justify-center rounded-xl hover:bg-slate-25 dark:hover:bg-slate-700 dark:hover:text-slate-100 hover:text-slate-600 relative transition-all duration-200 ease-smooth"
      :class="{
        'bg-woot-50 dark:bg-slate-100 text-woot-500 hover:bg-woot-50':
          isActive || isChildMenuActive,
      }"
      :rel="openInNewPage ? 'noopener noreferrer nofollow' : undefined"
      :target="openInNewPage ? '_blank' : undefined"
      @click="navigate"
    >
      <fluent-icon
        :icon="icon"
        :class="{
          'text-woot-500': isActive || isChildMenuActive,
        }"
      />
      <span class="sr-only">{{ name }}</span>
      <span
        v-if="beta"
        class="absolute -top-0.5 -right-0.5 px-1 py-0.5 text-[9px] font-semibold leading-none text-green-600 dark:text-green-400 bg-green-100 dark:bg-green-900/40 border border-green-400 dark:border-green-600 rounded"
      >
        {{ $t('SIDEBAR.BETA') }}
      </span>
      <span
        v-else-if="count"
        class="text-black-900 bg-yellow-500 absolute -top-1 -right-1"
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
    tooltipText() {
      if (this.beta) {
        return `${this.$t(`SIDEBAR.${this.name}`)} (${this.$t('SIDEBAR.BETA')})`;
      }
      return this.$t(`SIDEBAR.${this.name}`);
    },
  },
};
</script>
