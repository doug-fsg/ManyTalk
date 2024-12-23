import { frontendURL } from 'dashboard/helper/URLHelper';
import store from '../../../../store';
import { useAlert } from 'dashboard/composables';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ia'),
      name: 'settings_ia',
      meta: {
        permissions: ['administrator'], // Permissões necessárias
      },
      beforeEnter(to, from, next) {
        // Obtendo informações do usuário logado
        const user = store.getters.getCurrentUser;

        // const email = user?.account_id + "@manytalks.com.br";
        const email = user?.account_id
          ? `${user.account_id}@manytalks.com.br`
          : '';

        const name = user?.name;
        const accountId = user?.account_id;
        const image = user?.avatar_url;

        const apiURL = process.env.VUE_APP_API_URL;

        // Faz a requisição para obter o token
        fetch(`${apiURL}?email=${email}`)
          .then(response => response.json())
          .then(data => {
            if (data.token) {
              const redirectURL = `${apiURL}?email=${email}&name=${encodeURIComponent(
                name
              )}&manytalksAccountId=${accountId}&image=${image}&token=${
                data.token
              }`;
              window.open(redirectURL, '_blank'); // Abre a URL em uma nova aba
            } else {
              useAlert('Erro ao obter informações. Tente novamente.');
            }
          })
          .catch(() => {
            useAlert('Ocorreu um erro, por favor tente novamente mais tarde.');
          });

        next(false); // Impede a navegação interna para esta rota
      },
    },
  ],
};
