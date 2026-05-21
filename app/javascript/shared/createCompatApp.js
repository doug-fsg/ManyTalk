import { createApp, configureCompat } from 'vue';
import { compatConfig } from './compatConfig';

/**
 * Call once at module load to apply the global compat config.
 * Safe to call multiple times (idempotent).
 */
export function ensureCompat() {
  configureCompat(compatConfig);
}

/**
 * Drop-in replacement for `new Vue({ el, render })`.
 *
 * Usage:
 *   import { mountCompatApp } from 'shared/createCompatApp';
 *   mountCompatApp(RootComponent, '#app', (app) => {
 *     app.use(router).use(store);
 *   });
 *
 * @param {object}   RootComponent  - Vue SFC or options object
 * @param {string}   selector       - CSS selector of the mount target
 * @param {Function} [setup]        - optional callback to install plugins
 * @returns {import('vue').App}
 */
export function mountCompatApp(RootComponent, selector, setup) {
  ensureCompat();
  const app = createApp(RootComponent);
  if (typeof setup === 'function') {
    setup(app);
  }
  app.mount(selector);
  return app;
}
