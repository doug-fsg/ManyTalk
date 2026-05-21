import { configureCompat } from 'vue';
import { config } from '@vue/test-utils';

configureCompat({
  MODE: 2,
});

// Global mocks — avoids repeating $t / $bus in every spec file.
config.global.mocks = {
  $t: msg => (typeof msg === 'string' ? msg : String(msg)),
  $tc: msg => msg,
  $te: () => true,
  $d: val => val,
  $n: val => val,
  $bus: {
    $on: () => {},
    $off: () => {},
    $emit: () => {},
  },
};
