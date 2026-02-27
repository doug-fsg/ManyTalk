<template>
  <transition name="fade">
    <div v-if="show" class="onboarding-overlay">
      <div class="onboarding-card">
        <!-- Close Button -->
        <button
          class="close-btn"
          @click="dismiss"
          :aria-label="$t('ACTIVITIES.ONBOARDING.CTA')"
        >
          <fluent-icon icon="dismiss" size="20" />
        </button>

        <!-- Header -->
        <div class="onboarding-header">
          <div class="header-icon">
            <fluent-icon icon="calendar-clock" size="32" />
          </div>
          <h2 class="onboarding-title">{{ $t('ACTIVITIES.ONBOARDING.TITLE') }}</h2>
          <p class="onboarding-subtitle">
            {{ $t('ACTIVITIES.ONBOARDING.SUBTITLE') }}
          </p>
        </div>

        <!-- Content -->
        <div class="onboarding-content">
          <div class="feature-section">
            <div class="feature-icon task">
              <fluent-icon icon="checkmark-circle" size="20" />
            </div>
            <div>
              <h3 class="feature-title">{{ $t('ACTIVITIES.ONBOARDING.TASK_TITLE') }}</h3>
              <p class="feature-desc">{{ $t('ACTIVITIES.ONBOARDING.TASK_DESC') }}</p>
            </div>
          </div>

          <div class="feature-section">
            <div class="feature-icon message">
              <fluent-icon icon="chat" size="20" />
            </div>
            <div>
              <h3 class="feature-title">{{ $t('ACTIVITIES.ONBOARDING.MESSAGE_TITLE') }}</h3>
              <p class="feature-desc">{{ $t('ACTIVITIES.ONBOARDING.MESSAGE_DESC') }}</p>
            </div>
          </div>

          <div class="feature-section">
            <div class="feature-icon filter">
              <fluent-icon icon="filter" size="20" />
            </div>
            <div>
              <h3 class="feature-title">{{ $t('ACTIVITIES.ONBOARDING.FILTERS_TITLE') }}</h3>
              <p class="feature-desc">{{ $t('ACTIVITIES.ONBOARDING.FILTERS_DESC') }}</p>
            </div>
          </div>

          <div class="feature-section">
            <div class="feature-icon view">
              <fluent-icon icon="calendar" size="20" />
            </div>
            <div>
              <h3 class="feature-title">{{ $t('ACTIVITIES.ONBOARDING.VIEWS_TITLE') }}</h3>
              <p class="feature-desc">{{ $t('ACTIVITIES.ONBOARDING.VIEWS_DESC') }}</p>
            </div>
          </div>

          <div class="feature-section">
            <div class="feature-icon extra">
              <fluent-icon icon="star-emphasis" size="20" />
            </div>
            <div>
              <h3 class="feature-title">{{ $t('ACTIVITIES.ONBOARDING.EXTRA_TITLE') }}</h3>
              <p class="feature-desc">{{ $t('ACTIVITIES.ONBOARDING.EXTRA_DESC') }}</p>
            </div>
          </div>
        </div>

        <!-- CTA -->
        <div class="onboarding-actions">
          <button class="btn-primary" @click="dismiss">
            {{ $t('ACTIVITIES.ONBOARDING.CTA') }}
          </button>
        </div>
      </div>
    </div>
  </transition>
</template>

<script>
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { mapGetters } from 'vuex';

export default {
  name: 'ActivitiesOnboardingModal',
  components: { FluentIcon },

  data() {
    return {
      show: false,
    };
  },

  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
    }),
  },

  watch: {
    accountId: {
      handler(id) {
        if (id && !this.show) this.checkAndShow();
      },
      immediate: false,
    },
  },

  mounted() {
    this.$nextTick(() => {
      this.checkAndShow();
    });
  },

  methods: {
    open() {
      this.show = true;
    },

    checkAndShow() {
      if (!this.accountId) return;

      const seen = this.getSeenAccounts();
      if (!seen[this.accountId]) {
        this.show = true;
      }
    },

    getSeenAccounts() {
      return LocalStorage.get(LOCAL_STORAGE_KEYS.ACTIVITIES_ONBOARDING) || {};
    },

    dismiss() {
      const seen = this.getSeenAccounts();
      seen[this.accountId] = true;
      LocalStorage.set(LOCAL_STORAGE_KEYS.ACTIVITIES_ONBOARDING, seen);
      this.show = false;
    },
  },
};
</script>

<style lang="scss" scoped>
.onboarding-overlay {
  @apply fixed inset-0 z-[9999] flex items-center justify-center p-4;
  @apply bg-modal-backdrop-light dark:bg-modal-backdrop-dark;
}

.onboarding-card {
  @apply relative bg-white dark:bg-slate-800 rounded-2xl shadow-soft-xl max-w-2xl w-full;
  @apply border border-slate-200 dark:border-slate-700;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  animation: scaleIn 0.25s ease-out;
}

@keyframes scaleIn {
  from {
    opacity: 0;
    transform: scale(0.96);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

.close-btn {
  @apply absolute top-4 right-4 z-10 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 p-1.5 rounded-full hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors;
}

.onboarding-header {
  @apply text-center pt-8 pb-4 px-6;
  flex-shrink: 0;

  .header-icon {
    @apply inline-flex items-center justify-center w-16 h-16 rounded-2xl mb-4 bg-woot-500 text-white;
  }

  .onboarding-title {
    @apply text-xl font-bold text-slate-900 dark:text-slate-100 mb-2;
  }

  .onboarding-subtitle {
    @apply text-sm text-slate-600 dark:text-slate-400 leading-relaxed;
  }
}

.onboarding-content {
  @apply px-6 pb-4 overflow-y-auto;
  flex: 1;
  min-height: 0;
}

.feature-section {
  @apply flex gap-4 py-3 border-b border-slate-200 dark:border-slate-700 last:border-b-0;

  .feature-icon {
    @apply flex-shrink-0 w-10 h-10 rounded-lg flex items-center justify-center text-white;

    &.task {
      @apply bg-woot-500;
    }

    &.message {
      @apply bg-sky-500;
    }

    &.filter {
      @apply bg-violet-500;
    }

    &.view {
      @apply bg-amber-500;
    }

    &.extra {
      @apply bg-pink-500;
    }
  }

  .feature-title {
    @apply text-sm font-semibold text-slate-900 dark:text-slate-100 mb-1;
  }

  .feature-desc {
    @apply text-xs text-slate-600 dark:text-slate-400 leading-relaxed;
  }
}

.onboarding-actions {
  @apply p-6 pt-4 flex justify-center border-t border-slate-200 dark:border-slate-700;
  flex-shrink: 0;
}

.btn-primary {
  @apply inline-flex items-center px-6 py-2.5 text-sm font-medium rounded-lg text-white transition-all duration-200;
  @apply bg-woot-500 hover:bg-woot-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-woot-500;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.25s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
