<template>
  <banner
    v-if="shouldShowBanner"
    color-scheme="primary"
    :banner-message="bannerMessage"
    href-link="https://app.manytalks.com.br/hc/inovechat/articles/1715922311-many-talks-novidades-e-melhorias"
    :href-link-text="$t('GENERAL_SETTINGS.LEARN_MORE')"
    has-close-button
    @close="dismissUpdateBanner"
  />
</template>
<script>
import Banner from 'dashboard/components/ui/Banner.vue';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { LocalStorage } from 'shared/helpers/localStorage';
import { mapGetters } from 'vuex';
import adminMixin from 'dashboard/mixins/isAdmin';
import { hasAnUpdateAvailable } from './versionCheckHelper';

export default {
  components: { Banner },
  mixins: [adminMixin],
  props: {
    //latestChatwootVersion2: { type: String, default: '' },
    latestChatwootVersion2: { type: String, default: '5.9.0' }
  },
//   created() {
//   console.log('Versão atual do aplicativo:', this.globalConfig.appVersion);
//   console.log('Versão mais recente do Chatwoot:', this.latestChatwootVersion2);
// },

  data() {
    return { userDismissedBanner: false };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    updateAvailable() { 
      return hasAnUpdateAvailable(
        this.latestChatwootVersion2,
        this.globalConfig.appVersion
      );
    },
    bannerMessage() {
      return this.$t('GENERAL_SETTINGS.UPDATE_CHATWOOT', {
        latestChatwootVersion2: this.latestChatwootVersion2,
      });
    },
    shouldShowBanner() {
      return (
        !this.userDismissedBanner &&
        this.globalConfig.displayManifest &&
        this.updateAvailable &&
        !this.isVersionNotificationDismissed(this.latestChatwootVersion2) &&
        this.isAdmin
      );
    },
  },
  methods: {
    isVersionNotificationDismissed(version) {
      const dismissedVersions =
        LocalStorage.get(LOCAL_STORAGE_KEYS.DISMISSED_UPDATES) || [];
      return dismissedVersions.includes(version);
    },
    dismissUpdateBanner() {
      let updatedDismissedItems =
        LocalStorage.get(LOCAL_STORAGE_KEYS.DISMISSED_UPDATES) || [];
      if (updatedDismissedItems instanceof Array) {
        updatedDismissedItems.push(this.latestChatwootVersion2);
      } else {
        updatedDismissedItems = [this.latestChatwootVersion2];
      }
      LocalStorage.set(
        LOCAL_STORAGE_KEYS.DISMISSED_UPDATES,
        updatedDismissedItems
      );
      this.userDismissedBanner = true;
    },
  },
};
</script>
