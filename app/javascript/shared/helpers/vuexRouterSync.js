/**
 * Minimal replacement for vuex-router-sync compatible with Vue Router 4.
 * Keeps the same store.state.route contract used by dashboard components.
 */
function cloneRoute(to, from) {
  const clone = {
    name: to.name,
    path: to.path,
    hash: to.hash,
    query: to.query,
    params: to.params,
    fullPath: to.fullPath,
    meta: to.meta,
  };
  if (from) {
    clone.from = cloneRoute(from);
  }
  return Object.freeze(clone);
}

export function sync(store, router, options) {
  const moduleName = (options || {}).moduleName || 'route';

  // router.currentRoute is a Ref in Vue Router 4
  const initialRoute = router.currentRoute.value;

  store.registerModule(moduleName, {
    namespaced: false,
    state: () => cloneRoute(initialRoute),
    mutations: {
      'router/ROUTE_CHANGED'(state, transition) {
        const module = store.state[moduleName];
        const next = cloneRoute(transition.to, transition.from);
        Object.keys(next).forEach(key => {
          module[key] = next[key];
        });
        store.state[moduleName] = next;
      },
    },
  });

  router.afterEach((to, from) => {
    store.commit('router/ROUTE_CHANGED', { to, from });
  });
}
