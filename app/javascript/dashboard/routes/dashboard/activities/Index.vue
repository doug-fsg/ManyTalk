<template>
  <div class="activities-page-container flex flex-col h-full min-h-0 w-full overflow-hidden bg-slate-50 dark:bg-slate-900">
    <activities-onboarding-modal ref="onboardingModal" />
    <div class="flex-1 min-h-0 overflow-hidden">
      <activities-calendar
        ref="calendar"
        :show-create-button="true"
        :show-onboarding-button="true"
        :on-open-onboarding="openOnboarding"
        class="h-full"
      />
    </div>
  </div>
</template>

<script>
import ActivitiesCalendar from '../crm/components/ActivitiesCalendar.vue';
import ActivitiesOnboardingModal from './components/ActivitiesOnboardingModal.vue';

export default {
  name: 'ActivitiesIndex',
  components: {
    ActivitiesCalendar,
    ActivitiesOnboardingModal,
  },
  methods: {
    openOnboarding() {
      this.$refs.onboardingModal?.open();
    },
  },
};
</script>
