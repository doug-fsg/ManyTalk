import { computed, ref, unref } from 'vue';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { useStore } from 'dashboard/composables/store';

/** Always shown; cannot be toggled off. */
export const PINNED_COLUMN_KEYS = ['name'];

export const CUSTOM_ATTR_PREFIX = 'ca:';

/**
 * Optional standard columns. Keys match ContactsTable column `key` values.
 * `defaultVisible: false` keeps the list compact.
 */
export const OPTIONAL_COLUMN_DEFS = [
  { key: 'email', i18nKey: 'EMAIL_ADDRESS', defaultVisible: true },
  { key: 'phone_number', i18nKey: 'PHONE_NUMBER', defaultVisible: true },
  { key: 'company', i18nKey: 'COMPANY', defaultVisible: false },
  { key: 'city', i18nKey: 'CITY', defaultVisible: false },
  { key: 'country', i18nKey: 'COUNTRY', defaultVisible: false },
  { key: 'profiles', i18nKey: 'SOCIAL_PROFILES', defaultVisible: false },
  { key: 'last_activity_at', i18nKey: 'LAST_ACTIVITY', defaultVisible: true },
  { key: 'created_at', i18nKey: 'CREATED_AT', defaultVisible: false },
];

export const customAttributeColumnKey = attributeKey =>
  `${CUSTOM_ATTR_PREFIX}${attributeKey}`;

export const isCustomAttributeColumnKey = key =>
  typeof key === 'string' && key.startsWith(CUSTOM_ATTR_PREFIX);

export const attributeKeyFromColumnKey = key =>
  key.slice(CUSTOM_ATTR_PREFIX.length);

const STANDARD_OPTIONAL_KEYS = new Set(
  OPTIONAL_COLUMN_DEFS.map(col => col.key)
);

const defaultVisibleKeys = () =>
  OPTIONAL_COLUMN_DEFS.filter(col => col.defaultVisible).map(col => col.key);

const toCustomColumnDefs = attributeDefs =>
  (attributeDefs || []).map(attr => ({
    key: customAttributeColumnKey(attr.attribute_key),
    kind: 'custom',
    attributeKey: attr.attribute_key,
    label: attr.attribute_display_name,
    displayType: attr.attribute_display_type,
    defaultVisible: false,
  }));

const standardColumnDefs = () =>
  OPTIONAL_COLUMN_DEFS.map(col => ({ ...col, kind: 'standard' }));

const readStoredKeys = () => {
  try {
    const raw = localStorage.getItem(LOCAL_STORAGE_KEYS.CONTACT_TABLE_COLUMNS);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return null;
    // Keep standard keys + any custom-attribute keys (validated when defs load)
    return parsed.filter(
      key => STANDARD_OPTIONAL_KEYS.has(key) || isCustomAttributeColumnKey(key)
    );
  } catch {
    return null;
  }
};

const persistKeys = keys => {
  try {
    localStorage.setItem(
      LOCAL_STORAGE_KEYS.CONTACT_TABLE_COLUMNS,
      JSON.stringify(keys)
    );
  } catch {
    // Ignore quota / private mode errors
  }
};

const resolveAttributeDefs = options => {
  if (options.attributeDefs !== undefined) {
    return computed(() => unref(options.attributeDefs) || []);
  }

  return computed(() => {
    try {
      const store = useStore();
      return (
        store.getters['attributes/getAttributesByModel']('contact_attribute') ||
        []
      );
    } catch {
      return [];
    }
  });
};

/**
 * Manages which optional contact table columns are visible.
 * Name stays pinned. Preference persists in localStorage.
 * Includes standard fields and contact custom attributes.
 *
 * @param {{ attributeDefs?: import('vue').Ref|Array }} [options]
 */
export function useContactTableColumns(options = {}) {
  const attributeDefs = resolveAttributeDefs(options);

  const optionalColumns = computed(() => [
    ...standardColumnDefs(),
    ...toCustomColumnDefs(attributeDefs.value),
  ]);

  const allowedOptionalKeys = computed(() =>
    optionalColumns.value.map(col => col.key)
  );

  const visibleOptionalKeys = ref(readStoredKeys() || defaultVisibleKeys());

  const visibleColumnKeys = computed(() => [
    ...PINNED_COLUMN_KEYS,
    ...visibleOptionalKeys.value,
  ]);

  const isOptionalVisible = key => visibleOptionalKeys.value.includes(key);

  const toggleOptionalColumn = key => {
    if (!allowedOptionalKeys.value.includes(key)) return;

    const next = new Set(visibleOptionalKeys.value);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    const ordered = optionalColumns.value
      .map(col => col.key)
      .filter(k => next.has(k));
    visibleOptionalKeys.value = ordered;
    persistKeys(ordered);
  };

  const setOptionalVisible = (key, visible) => {
    const isVisible = isOptionalVisible(key);
    if (visible === isVisible) return;
    toggleOptionalColumn(key);
  };

  return {
    optionalColumns,
    visibleOptionalKeys,
    visibleColumnKeys,
    isOptionalVisible,
    toggleOptionalColumn,
    setOptionalVisible,
  };
}
