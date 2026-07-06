<template>
  <woot-button
    v-tooltip.right="$t(`SIDEBAR.PROFILE_SETTINGS`)"
    variant="link"
    class="group items-center flex rounded-full w-10 h-10 justify-center transition-all duration-200 ease-out hover:bg-white/15 dark:hover:bg-white/10 motion-reduce:transition-none"
    @click="handleClick"
  >
    <thumbnail
      :src="currentUser.avatar_url"
      :username="currentUser.name"
      :status="statusOfAgent"
      should-show-status-always
      size="32px"
    />
  </woot-button>
</template>
<script>
import { mapGetters } from 'vuex';
import Thumbnail from '../../widgets/Thumbnail.vue';

export default {
  components: {
    Thumbnail,
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      currentUserAvailability: 'getCurrentUserAvailability',
    }),
    statusOfAgent() {
      return this.currentUserAvailability || 'offline';
    },
  },
  methods: {
    handleClick() {
      this.$emit('toggle-menu');
    },
  },
};
</script>
