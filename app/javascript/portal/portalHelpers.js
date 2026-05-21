import slugifyWithCounter from '@sindresorhus/slugify';
import { createApp, h, configureCompat } from 'vue';

import PublicArticleSearch from './components/PublicArticleSearch.vue';
import TableOfContents from './components/TableOfContents.vue';
import { initializeTheme } from './portalThemeHelper.js';
import { registerPortalGlobals } from './portalAppConfig';
import { compatConfig } from 'shared/compatConfig';

configureCompat(compatConfig);

/** @type {{ el: Element, app: import('vue').App }[]} */
const mountedPortalApps = [];

export function unmountAllPortalApps() {
  mountedPortalApps.forEach(({ app }) => {
    app.unmount();
  });
  mountedPortalApps.length = 0;
}

function mountPortalApp(el, render) {
  const existing = mountedPortalApps.find(entry => entry.el === el);
  if (existing) {
    existing.app.unmount();
    const idx = mountedPortalApps.indexOf(existing);
    mountedPortalApps.splice(idx, 1);
  }

  const app = createApp({ render });
  registerPortalGlobals(app);
  app.mount(el);
  mountedPortalApps.push({ el, app });
  return app;
}

export function setupPortalTurbolinks() {
  document.addEventListener('turbolinks:before-cache', unmountAllPortalApps);
  document.addEventListener('turbolinks:before-render', unmountAllPortalApps);
}

export const getHeadingsfromTheArticle = () => {
  const rows = [];
  const articleElement = document.getElementById('cw-article-content');
  if (!articleElement) {
    return rows;
  }

  articleElement.querySelectorAll('h1, h2, h3').forEach(element => {
    const slug = slugifyWithCounter(element.innerText);
    element.id = slug;
    element.className = 'scroll-mt-24 heading';
    element.innerHTML += `<a class="permalink text-slate-600 ml-3" href="#${slug}" title="${element.innerText}" data-turbolinks="false">#</a>`;
    rows.push({
      slug,
      title: element.innerText,
      tag: element.tagName.toLowerCase(),
    });
  });
  return rows;
};

export const openExternalLinksInNewTab = () => {
  const { customDomain, hostURL } = window.portalConfig;
  const isSameHost =
    window.location.href.includes(customDomain) ||
    window.location.href.includes(hostURL);

  // Modify external links only on articles page
  const isOnArticlePage =
    isSameHost && document.querySelector('#cw-article-content') !== null;

  document.addEventListener('click', function (event) {
    if (!isOnArticlePage) return;

    // Some of the links come wrapped in strong tag through prosemirror

    const isTagAnchor = event.target.tagName === 'A';
    const isParentTagAnchor =
      event.target.tagName === 'STRONG' &&
      event.target.parentNode.tagName === 'A';

    if (isTagAnchor || isParentTagAnchor) {
      const link = isTagAnchor ? event.target : event.target.parentNode;

      const isInternalLink =
        link.hostname === window.location.hostname ||
        link.href.includes(customDomain) ||
        link.href.includes(hostURL);

      if (!isInternalLink) {
        link.target = '_blank';
        link.rel = 'noopener noreferrer'; // Security and performance benefits
        // Prevent default if you want to stop the link from opening in the current tab
        event.stopPropagation();
      }
    }
  });
};

export const InitializationHelpers = {
  navigateToLocalePage: () => {
    const allLocaleSwitcher = document.querySelector('.locale-switcher');

    if (!allLocaleSwitcher) {
      return false;
    }

    const { portalSlug } = allLocaleSwitcher.dataset;
    allLocaleSwitcher.addEventListener('change', event => {
      window.location = `/hc/${portalSlug}/${event.target.value}/`;
    });
    return false;
  },

  initializeSearch: () => {
    const isSearchContainerAvailable = document.querySelector('#search-wrap');
    if (isSearchContainerAvailable) {
      mountPortalApp(isSearchContainerAvailable, () => h(PublicArticleSearch));
    }
  },

  initializeTableOfContents: () => {
    const isOnArticlePage = document.querySelector('#cw-hc-toc');
    if (isOnArticlePage) {
      const rows = getHeadingsfromTheArticle();
      mountPortalApp(isOnArticlePage, () => h(TableOfContents, { rows }));
    }
  },

  appendPlainParamToURLs: () => {
    document.getElementsByTagName('a').forEach(aTagElement => {
      if (aTagElement.href && aTagElement.href.includes('/hc/')) {
        const url = new URL(aTagElement.href);
        url.searchParams.set('show_plain_layout', 'true');

        aTagElement.setAttribute('href', url);
      }
    });
  },

  initializeThemesInPortal: initializeTheme,

  initialize: () => {
    openExternalLinksInNewTab();
    if (window.portalConfig.isPlainLayoutEnabled === 'true') {
      InitializationHelpers.appendPlainParamToURLs();
    } else {
      InitializationHelpers.initializeThemesInPortal();
      InitializationHelpers.navigateToLocalePage();
      InitializationHelpers.initializeSearch();
      InitializationHelpers.initializeTableOfContents();
    }
  },

  onLoad: () => {
    InitializationHelpers.initialize();
    if (window.location.hash) {
      if ('scrollRestoration' in window.history) {
        window.history.scrollRestoration = 'manual';
      }

      const a = document.createElement('a');
      a.href = window.location.hash;
      a['data-turbolinks'] = false;
      a.click();
    }
  },
};
