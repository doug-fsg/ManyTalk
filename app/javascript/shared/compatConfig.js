/**
 * Vue 3 compat-mode configuration.
 *
 * MODE: 2 means "Vue 2 compat" — all Vue 2 behaviour is kept by default.
 * Used by all packs except v3app (login/signup pilot).
 *
 * Reference: https://v3-migration.vuejs.org/migration-build.html
 */
export const compatConfig = {
  MODE: 2,
};

/**
 * Stricter config for the v3app (login/signup) pilot.
 * MODE: 3 = Vue 3 default; Vue 2 APIs still work but emit deprecation warnings.
 * Use this to surface remaining Vue 2 patterns in the v3app before removing
 * @vue/compat entirely from that pack.
 */
export const compatConfigV3App = {
  MODE: 3,
  // Keep these true to avoid breaking v3app components that still use them:
  COMPONENT_FUNCTIONAL: true,
  COMPONENT_V_MODEL: true,
  RENDER_FUNCTION: true,
};
