export const openVariableQuery = (value, cursor) => {
  const text = String(value || '');
  const end = cursor == null ? text.length : cursor;
  const before = text.slice(0, end);
  const open = before.lastIndexOf('{');
  if (open === -1) return null;

  const fragment = before.slice(open);
  if (fragment.includes('}')) return null;

  return {
    start: open,
    search: fragment.replace(/^\{+/, ''),
  };
};

export const applyVariableToken = (value, token, cursor) => {
  const text = String(value || '');
  const end = cursor == null ? text.length : cursor;
  const query = openVariableQuery(text, end);
  const prefix = query ? text.slice(0, query.start) : text.slice(0, end);
  const suffix = text.slice(end);
  const spacer =
    !query && prefix && !prefix.endsWith(' ') && !prefix.endsWith('\n')
      ? ' '
      : '';
  const next = `${prefix}${spacer}${token}${suffix}`;
  return {
    value: next,
    cursor: prefix.length + spacer.length + token.length,
  };
};
