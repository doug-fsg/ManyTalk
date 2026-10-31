const TOKEN_PREFIX = 'anexo';
export const MAX_TOKEN_KEY_LENGTH = 24;
export const TOKEN_CAPTURE = /\{\{anexo:([a-z0-9_.-]+)\}\}/gi;

export const tokenFor = key => `{{${TOKEN_PREFIX}:${key}}}`;

export const normalizeTokenKey = key =>
  String(key || '')
    .toLowerCase()
    .replace(/\.[^.]+$/, '')
    .replace(/_/g, '-');

export const slugFromFilename = filename => {
  const base = String(filename || '')
    .replace(/\.[^.]+$/, '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^[-_]+|[-_]+$/g, '');
  return base || 'arquivo';
};

export const uniqueKey = (filename, usedKeys = []) => {
  const base = slugFromFilename(filename);
  if (!usedKeys.includes(base)) return base;
  let index = 2;
  while (usedKeys.includes(`${base}-${index}`)) {
    index += 1;
  }
  return `${base}-${index}`;
};

export const tokenFromFilename = (filename, usedKeys = []) => {
  const key = uniqueKey(filename, usedKeys);
  return { key, token: tokenFor(key) };
};

export const slugFromName = name =>
  slugFromFilename(name).slice(0, MAX_TOKEN_KEY_LENGTH);

export const isValidTokenKey = key =>
  /^[a-z0-9][a-z0-9_-]{1,23}$/.test(String(key || ''));

export const tokensInText = text => {
  const matches = [];
  const pattern = new RegExp(TOKEN_CAPTURE.source, 'gi');
  let match = pattern.exec(String(text || ''));
  while (match) {
    matches.push({ token: match[0], key: match[1] });
    match = pattern.exec(String(text || ''));
  }
  return matches;
};

export const tokenStatus = (text, fileItems = []) => {
  const known = (fileItems || []).map(item =>
    normalizeTokenKey(item.tokenKey || item.key || '')
  );
  return tokensInText(text).map(entry => {
    const normalized = normalizeTokenKey(entry.key);
    const linked = known.includes(normalized);
    const file = (fileItems || []).find(
      item => normalizeTokenKey(item.tokenKey || item.key || '') === normalized
    );
    return {
      ...entry,
      linked,
      filename: file?.filename || file?.description || '',
    };
  });
};
