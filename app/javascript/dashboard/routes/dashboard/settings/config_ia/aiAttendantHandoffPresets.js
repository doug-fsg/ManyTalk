export const HANDOFF_PRESET_KEYS = [
  'ask_human',
  'complaint',
  'unknown',
  'cancel',
  'payment',
  'legal',
  'urgent',
];

const linesFrom = value =>
  String(value || '')
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean);

export const parseHandoffConditions = (text, labelsByKey = {}) => {
  const labelToKey = Object.fromEntries(
    Object.entries(labelsByKey).map(([key, label]) => [String(label).trim(), key])
  );
  const selected = [];
  const leftover = [];

  linesFrom(text).forEach(line => {
    const key = labelToKey[line];
    if (key && !selected.includes(key)) {
      selected.push(key);
      return;
    }
    leftover.push(line);
  });

  return { selected, extra: leftover.join('\n') };
};

export const serializeHandoffConditions = (
  selectedKeys = [],
  extra = '',
  labelsByKey = {}
) => {
  const fromPresets = selectedKeys
    .map(key => String(labelsByKey[key] || '').trim())
    .filter(Boolean);
  return [...fromPresets, ...linesFrom(extra)].join('\n');
};
