import { onClickOutside } from '@vueuse/core';

/**
 * Vue 3 directive replacing vue-clickaway.
 * Usage: v-on-clickaway="handler" (global name: on-clickaway)
 * Local: directives: { onClickaway: onClickAwayDirective }
 */
function bindClickOutside(el, handler) {
  if (typeof handler !== 'function') {
    return;
  }

  if (el.__onClickOutsideStop) {
    el.__onClickOutsideStop();
  }

  el.__onClickOutsideStop = onClickOutside(el, event => {
    handler(event);
  });
}

export const onClickAwayDirective = {
  mounted(el, binding) {
    bindClickOutside(el, binding.value);
  },
  updated(el, binding) {
    bindClickOutside(el, binding.value);
  },
  unmounted(el) {
    if (el.__onClickOutsideStop) {
      el.__onClickOutsideStop();
      el.__onClickOutsideStop = null;
    }
  },
};

export default onClickAwayDirective;
