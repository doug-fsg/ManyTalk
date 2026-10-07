<script setup>
import { useStoreGetters } from 'dashboard/composables/store';
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { getUserPermissions, hasPermissions } from '../helper/permissionsHelper';
const props = defineProps({
  permissions: {
    type: Array,
    required: true,
  },
});

const getters = useStoreGetters();
const { accountId } = useAccount();
const user = getters.getCurrentUser.value;
const hasPermission = computed(() =>
  hasPermissions(
    props.permissions,
    getUserPermissions(user, accountId.value)
  )
);
</script>

<template>
  <div v-if="hasPermission">
    <slot />
  </div>
</template>
