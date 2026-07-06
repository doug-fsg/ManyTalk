import {
  getPrimaryMenuKeyForRoute,
  resolvePrimaryMenuItem,
} from '../primaryMenuHelper';

describe('primaryMenuHelper', () => {
  describe('getPrimaryMenuKeyForRoute', () => {
    it('maps inbox view routes', () => {
      expect(getPrimaryMenuKeyForRoute({ name: 'inbox_view', path: '' })).toBe(
        'inboxView'
      );
    });

    it('maps help center by path', () => {
      expect(
        getPrimaryMenuKeyForRoute({
          name: 'edit_article',
          path: '/app/accounts/1/portals/wiki/en/articles/1',
        })
      ).toBe('helpcenter');
    });

    it('returns null for unknown routes', () => {
      expect(getPrimaryMenuKeyForRoute({ name: 'home', path: '' })).toBeNull();
    });
  });

  describe('resolvePrimaryMenuItem', () => {
    const helpCenterItem = {
      key: 'helpcenter',
      toState: '/app/accounts/158/portals',
      toStateName: 'default_portal_articles',
    };

    it('redirects agents to list_all_portals', () => {
      const resolved = resolvePrimaryMenuItem(helpCenterItem, {
        accountId: 158,
        currentRole: 'agent',
      });

      expect(resolved.toState).toBe('/app/accounts/158/portals/all');
      expect(resolved.toStateName).toBe('list_all_portals');
    });

    it('keeps admin destination unchanged', () => {
      const resolved = resolvePrimaryMenuItem(helpCenterItem, {
        accountId: 158,
        currentRole: 'administrator',
      });

      expect(resolved).toEqual(helpCenterItem);
    });
  });
});
