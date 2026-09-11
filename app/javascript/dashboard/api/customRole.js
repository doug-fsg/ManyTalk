import ApiClient from './ApiClient';

class CustomRoleAPI extends ApiClient {
  constructor() {
    super('custom_roles', { accountScoped: true });
  }
}

export default new CustomRoleAPI();
