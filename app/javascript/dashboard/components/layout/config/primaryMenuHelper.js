const ROUTE_NAME_TO_PRIMARY_KEY = {
  inbox_view: 'inboxView',
  inbox_view_conversation: 'inboxView',
  kanban_view: 'kanban',
  activities_view: 'activities',
  notifications_index: 'conversations',
};

export const getPrimaryMenuKeyForRoute = route => {
  if (!route?.name) return null;

  const fromName = ROUTE_NAME_TO_PRIMARY_KEY[route.name];
  if (fromName) return fromName;

  const path = route.path || '';
  if (path.includes('/portals')) return 'helpcenter';
  if (path.includes('/inbox-view')) return 'inboxView';
  if (path.includes('/kanban')) return 'kanban';
  if (path.includes('/activities')) return 'activities';

  return null;
};

export const resolvePrimaryMenuItem = (menuItem, { accountId, currentRole }) => {
  if (menuItem.key !== 'helpcenter' || currentRole === 'administrator') {
    return menuItem;
  }

  return {
    ...menuItem,
    toState: menuItem.toState.replace(/\/portals\/?$/, '/portals/all'),
    toStateName: 'list_all_portals',
  };
};
