import {
  AI_ATTENDANT_AVATARS,
  avatarPreviewUrl,
  avatarUrl,
  isValidAvatarId,
} from '../aiAttendantAvatars';

describe('aiAttendantAvatars', () => {
  it('lists six avatars', () => {
    expect(AI_ATTENDANT_AVATARS).toHaveLength(6);
  });

  it('builds a public url and rejects unknown ids', () => {
    expect(avatarUrl('avatar_5')).toBe('/ai_attendant/avatars/avatar_5.png');
    expect(avatarUrl('missing')).toBe('/ai_attendant/avatars/avatar_1.png');
    expect(avatarPreviewUrl('avatar_5')).toBe(
      '/ai_attendant/avatars/preview/avatar_5.jpg'
    );
    expect(avatarPreviewUrl('missing')).toBe(
      '/ai_attendant/avatars/preview/avatar_1.jpg'
    );
    expect(isValidAvatarId('avatar_1')).toBe(true);
    expect(isValidAvatarId('other')).toBe(false);
  });
});
