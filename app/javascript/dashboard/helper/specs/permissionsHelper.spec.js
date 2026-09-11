import {
  buildPermissionsFromRouter,
  hasPermissions,
} from '../permissionsHelper';

describe('hasPermissions', () => {
  it('returns true if permission is present', () => {
    expect(
      hasPermissions(['contact_manage'], ['team_manage', 'contact_manage'])
    ).toBe(true);
    expect(
      hasPermissions(['administrator', 'report_manage'], ['custom_role', 'report_manage'])
    ).toBe(true);
  });

  it('returns false if permission is not present', () => {
    expect(
      hasPermissions(['contact_manage'], ['team_manage', 'user_manage'])
    ).toBe(false);
    expect(hasPermissions()).toBe(false);
    expect(hasPermissions([])).toBe(false);
  });

  it('does not grant agent routes to custom roles without explicit permissions', () => {
    expect(
      hasPermissions(['administrator', 'agent', 'campaign_manage'], ['custom_role', 'report_manage'])
    ).toBe(false);
  });

  it('allows custom role agents into conversation routes with conversation permissions', () => {
    expect(
      hasPermissions(
        ['administrator', 'agent', 'conversation_participating_manage'],
        ['custom_role', 'conversation_participating_manage']
      )
    ).toBe(true);
  });

  it('keeps default agent access for non-custom-role users', () => {
    expect(hasPermissions(['administrator', 'agent'], ['agent'])).toBe(true);
  });
});

describe('buildPermissionsFromRouter', () => {
  it('returns a valid object when routes have permissions defined', () => {
    expect(
      buildPermissionsFromRouter([
        {
          path: 'agent',
          name: 'agent_list',
          meta: { permissions: ['agent_admin'] },
        },
        {
          path: 'inbox',
          children: [
            {
              path: '',
              name: 'inbox_list',
              meta: { permissions: ['inbox_admin'] },
            },
          ],
        },
        {
          path: 'conversations',
          children: [
            {
              path: '',
              children: [
                {
                  path: 'attachments',
                  name: 'attachments_list',
                  meta: { permissions: ['conversation_admin'] },
                },
              ],
            },
          ],
        },
      ])
    ).toEqual({
      agent_list: ['agent_admin'],
      inbox_list: ['inbox_admin'],
      attachments_list: ['conversation_admin'],
    });
  });

  it('throws an error if a named routed does not have permissions defined', () => {
    expect(() => {
      buildPermissionsFromRouter([
        {
          path: 'agent',
          name: 'agent_list',
        },
      ]);
    }).toThrow("The route doesn't have the required permissions defined");

    expect(() => {
      buildPermissionsFromRouter([
        {
          path: 'agent',
          name: 'agent_list',
          meta: {},
        },
      ]);
    }).toThrow("The route doesn't have the required permissions defined");
  });
});
