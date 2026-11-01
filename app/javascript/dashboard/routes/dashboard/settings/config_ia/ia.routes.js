import { frontendURL } from 'dashboard/helper/URLHelper';
import store from '../../../../store';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const SettingsContent = () => import('../Wrapper.vue');
const SettingsWrapper = () => import('../SettingsWrapper.vue');
const Index = () => import('./Index.vue');
const Editor = () => import('./Editor.vue');

function accountFeatureEnabled(accountId, feature) {
  return store.getters['accounts/isFeatureEnabledonAccount'](
    Number(accountId),
    feature
  );
}

function nativeAiEnabled(accountId) {
  return accountFeatureEnabled(accountId, FEATURE_FLAGS.ATENDIMENTO_IA_NATIVO);
}

function openLegacyManyIa(next) {
  const user = store.getters.getCurrentUser;

  if (!user) {
    useAlert('Usuário não autenticado.');
    next(false);
    return;
  }

  const email = user.account_id ? `${user.account_id}@manytalks.com.br` : '';
  const name = user.name || 'Desconhecido';
  const accountId = user.account_id || 'Sem Account ID';
  const image = user.avatar_url || 'Sem Avatar';
  const apiURL = process.env.VUE_APP_API_URL;

  if (!apiURL) {
    useAlert('Erro interno: URL da API não configurada.');
    next(false);
    return;
  }

  fetch(`${apiURL}?email=${email}`)
    .then(response => {
      if (!response.ok) {
        throw new Error(`Erro HTTP! Status: ${response.status}`);
      }
      return response.json();
    })
    .then(data => {
      if (!data.token) {
        useAlert('Erro ao obter informações. Tente novamente.');
        return;
      }

      const redirectURL = `${apiURL}?email=${email}&name=${encodeURIComponent(
        name
      )}&manytalksAccountId=${accountId}&image=${image}&token=${data.token}`;
      window.open(redirectURL, '_blank');
    })
    .catch(() => {
      useAlert('Ocorreu um erro, por favor tente novamente mais tarde.');
    });

  next(false);
}

function guardIaIndex(to, _from, next) {
  const accountId = to.params.accountId;
  if (nativeAiEnabled(accountId)) {
    next();
    return;
  }

  if (accountFeatureEnabled(accountId, FEATURE_FLAGS.IA)) {
    openLegacyManyIa(next);
    return;
  }

  next(false);
}

function guardNativeEditor(to, _from, next) {
  if (nativeAiEnabled(to.params.accountId)) {
    next();
    return;
  }

  next(false);
}

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ia'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'settings_ia',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
          beforeEnter: guardIaIndex,
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/ia'),
      component: SettingsContent,
      props: () => {
        return {
          headerTitle: 'AI_ATTENDANT.HEADER',
          icon: 'window-new',
          showBackButton: true,
          backUrl: { name: 'settings_ia' },
        };
      },
      children: [
        {
          path: ':configId/edit',
          name: 'settings_ia_edit',
          component: Editor,
          meta: {
            permissions: ['administrator'],
          },
          beforeEnter: guardNativeEditor,
        },
        {
          path: 'new',
          name: 'settings_ia_new',
          component: Editor,
          meta: {
            permissions: ['administrator'],
          },
          beforeEnter: guardNativeEditor,
        },
      ],
    },
  ],
};
