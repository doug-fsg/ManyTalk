import VueDOMPurifyHTML from 'vue-dompurify-html';
import { domPurifyConfig } from 'shared/helpers/HTMLSanitizer';
import onClickAwayDirective from 'shared/directives/onClickOutside';

/** Shared plugin/directive registration for portal micro-apps. */
export function registerPortalGlobals(app) {
  app.use(VueDOMPurifyHTML, domPurifyConfig);
  app.directive('on-clickaway', onClickAwayDirective);
}
