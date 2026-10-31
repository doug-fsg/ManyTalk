export const AI_ATTENDANT_AVATAR_IDS = [
  'avatar_1',
  'avatar_2',
  'avatar_3',
  'avatar_4',
  'avatar_5',
  'avatar_6',
];

export const AI_ATTENDANT_AVATARS = AI_ATTENDANT_AVATAR_IDS.map(id => ({ id }));

export const DEFAULT_AVATAR_ID = 'avatar_1';

export const resolveAvatarId = id =>
  AI_ATTENDANT_AVATAR_IDS.includes(id) ? id : DEFAULT_AVATAR_ID;

/** Full asset (~400 KB). Prefer avatarPreviewUrl in the UI. */
export const avatarUrl = id =>
  `/ai_attendant/avatars/${resolveAvatarId(id)}.png`;

/** Lightweight preview for lists and the picker (~15 KB). */
export const avatarPreviewUrl = id =>
  `/ai_attendant/avatars/preview/${resolveAvatarId(id)}.jpg`;

export const isValidAvatarId = id => AI_ATTENDANT_AVATAR_IDS.includes(id);
