import { beforeEach, describe, expect, it } from 'vitest';
import { ref } from 'vue';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import {
  OPTIONAL_COLUMN_DEFS,
  customAttributeColumnKey,
  useContactTableColumns,
} from '../useContactTableColumns';

describe('useContactTableColumns', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('starts with default visible optional columns', () => {
    const { visibleOptionalKeys, visibleColumnKeys } = useContactTableColumns({
      attributeDefs: [],
    });

    expect(visibleColumnKeys.value).toContain('name');
    expect(visibleOptionalKeys.value).toEqual(
      OPTIONAL_COLUMN_DEFS.filter(col => col.defaultVisible).map(col => col.key)
    );
  });

  it('toggles a column and persists preference', () => {
    const { toggleOptionalColumn, isOptionalVisible, visibleOptionalKeys } =
      useContactTableColumns({ attributeDefs: [] });

    expect(isOptionalVisible('company')).toBe(false);
    toggleOptionalColumn('company');
    expect(isOptionalVisible('company')).toBe(true);

    const stored = JSON.parse(
      localStorage.getItem(LOCAL_STORAGE_KEYS.CONTACT_TABLE_COLUMNS)
    );
    expect(stored).toEqual(visibleOptionalKeys.value);
  });

  it('restores preference from localStorage', () => {
    localStorage.setItem(
      LOCAL_STORAGE_KEYS.CONTACT_TABLE_COLUMNS,
      JSON.stringify(['email', 'company'])
    );

    const { visibleOptionalKeys } = useContactTableColumns({
      attributeDefs: [],
    });
    expect(visibleOptionalKeys.value).toEqual(['email', 'company']);
  });

  it('includes contact custom attributes as optional columns', () => {
    const attributeDefs = ref([
      {
        attribute_key: 'cpf',
        attribute_display_name: 'CPF',
        attribute_display_type: 'text',
      },
    ]);

    const { optionalColumns, toggleOptionalColumn, visibleColumnKeys } =
      useContactTableColumns({ attributeDefs });

    const customKey = customAttributeColumnKey('cpf');
    expect(optionalColumns.value.some(col => col.key === customKey)).toBe(
      true
    );

    toggleOptionalColumn(customKey);
    expect(visibleColumnKeys.value).toContain(customKey);
  });
});
