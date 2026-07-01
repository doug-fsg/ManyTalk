import {
  normalizeAttributeValues,
  listOptionsFromField,
  isListField,
  enrichDefinitionFields,
  enrichCustomField,
} from '../formFieldHelpers';

describe('formFieldHelpers', () => {
  describe('normalizeAttributeValues', () => {
    it('returns string arrays unchanged', () => {
      expect(normalizeAttributeValues(['A', 'B'])).toEqual(['A', 'B']);
    });

    it('extracts name from object array', () => {
      expect(
        normalizeAttributeValues([
          { name: 'Básico', color: '#111' },
          { name: 'Premium', color: '#222' },
        ])
      ).toEqual(['Básico', 'Premium']);
    });

    it('extracts labels from nested stages array', () => {
      expect(
        normalizeAttributeValues({
          stages: [{ name: 'Estágio 1' }, { name: 'Estágio 2' }],
        })
      ).toEqual(['Estágio 1', 'Estágio 2']);
    });

    it('extracts keys from stages hash map', () => {
      expect(
        normalizeAttributeValues({
          stages: {
            'Estágio 1': { color: '#aaa' },
            'Estágio 2': { color: '#bbb' },
          },
        })
      ).toEqual(['Estágio 1', 'Estágio 2']);
    });

    it('ignores empty objects from corrupted saves', () => {
      expect(normalizeAttributeValues([{}])).toEqual([]);
    });
  });

  describe('listOptionsFromField', () => {
    it('returns options for list custom attribute fields', () => {
      const field = {
        type: 'custom_attribute',
        attribute_display_type: 'list',
        attribute_values: [{ name: 'A' }, { name: 'B' }],
      };

      expect(listOptionsFromField(field)).toEqual(['A', 'B']);
    });
  });

  describe('isListField', () => {
    it('detects list fields by display type', () => {
      expect(
        isListField({
          type: 'custom_attribute',
          attribute_display_type: 'list',
        })
      ).toBe(true);
    });

    it('detects list fields by numeric display type', () => {
      expect(
        isListField({
          type: 'custom_attribute',
          attribute_display_type: 6,
        })
      ).toBe(true);
    });
  });

  describe('enrichCustomField', () => {
    it('prefers attribute store values for list fields', () => {
      const field = {
        type: 'custom_attribute',
        attribute_key: 'plan_type',
        attribute_display_type: 'list',
        attribute_values: [{}],
      };
      const contactAttributes = [
        {
          attribute_key: 'plan_type',
          attribute_display_type: 'list',
          attribute_values: [{ name: 'Básico' }, { name: 'Premium' }],
        },
      ];

      const enriched = enrichCustomField(field, contactAttributes);
      expect(enriched.attribute_values).toEqual(['Básico', 'Premium']);
    });
  });

  describe('enrichDefinitionFields', () => {
    it('enriches fields when contact attributes are provided', () => {
      const fields = [
        {
          key: 'cf_plan_type',
          type: 'custom_attribute',
          attribute_key: 'plan_type',
          attribute_display_type: 'list',
          attribute_values: [{}],
        },
      ];
      const contactAttributes = [
        {
          attribute_key: 'plan_type',
          attribute_display_type: 'list',
          attribute_values: [{ name: 'Básico' }],
        },
      ];

      const enriched = enrichDefinitionFields(fields, contactAttributes);
      expect(enriched[0].attribute_values).toEqual(['Básico']);
    });
  });
});
