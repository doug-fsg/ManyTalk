<script>
export default {
  computed: {
    items() {
      const data = this.$t('TEAMS_SETTINGS.EDIT_FLOW.WIZARD');
      return data;
    },
  },
};
</script>

<template>
  <div
    class="overflow-auto p-4 max-w-full my-auto flex flex-row flex-nowrap h-full bg-slate-25 dark:bg-slate-800"
  >
    <woot-wizard class="hidden md:block w-1/4" :items="items" />
    <router-view />
  </div>
</template>
