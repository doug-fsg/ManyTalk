import {
  applySavedTemplateDefaults,
  buildTemplateDefaultsKey,
  buildTemplateDefaultsSettingsUpdate,
  getSavedTemplateDefaults,
} from '../whatsappTemplateDefaultsHelper';

describe('whatsappTemplateDefaultsHelper', () => {
  const template = { name: 'bom_dia', language: 'pt_BR' };

  describe('buildTemplateDefaultsKey', () => {
    it('builds a stable key from template name and language', () => {
      expect(buildTemplateDefaultsKey(template)).toBe('bom_dia:pt_BR');
    });
  });

  describe('getSavedTemplateDefaults', () => {
    it('returns saved defaults for the template key', () => {
      const uiSettings = {
        whatsapp_template_defaults: {
          'bom_dia:pt_BR': { '1': '{{contact.first_name}}' },
        },
      };

      expect(getSavedTemplateDefaults(uiSettings, template)).toEqual({
        '1': '{{contact.first_name}}',
      });
    });
  });

  describe('applySavedTemplateDefaults', () => {
    it('applies saved legacy defaults without changing unknown keys', () => {
      const base = { '1': '', '2': '' };
      const saved = { '1': '{{contact.first_name}}' };

      expect(applySavedTemplateDefaults(base, saved)).toEqual({
        '1': '{{contact.first_name}}',
        '2': '',
      });
    });

    it('applies saved enhanced defaults deeply', () => {
      const base = {
        body: { '1': '' },
        header: { media_url: '', media_type: 'image' },
      };
      const saved = {
        body: { '1': '{{contact.first_name}}' },
        header: { media_url: 'https://example.com/image.png' },
      };

      expect(applySavedTemplateDefaults(base, saved)).toEqual({
        body: { '1': '{{contact.first_name}}' },
        header: {
          media_url: 'https://example.com/image.png',
          media_type: 'image',
        },
      });
    });
  });

  describe('buildTemplateDefaultsSettingsUpdate', () => {
    it('returns null when there is nothing to save', () => {
      expect(
        buildTemplateDefaultsSettingsUpdate({}, template, { '1': '  ' })
      ).toBeNull();
    });

    it('stores sanitized defaults under ui settings key', () => {
      const update = buildTemplateDefaultsSettingsUpdate(
        {},
        template,
        { '1': ' {{contact.first_name}} ' }
      );

      expect(update).toEqual({
        whatsapp_template_defaults: {
          'bom_dia:pt_BR': { '1': '{{contact.first_name}}' },
        },
      });
    });
  });
});
