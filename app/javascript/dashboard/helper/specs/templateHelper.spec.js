import {
  allKeysRequired,
  buildTemplateParameters,
  getHeaderMediaBadgeLabel,
  getHeaderMediaFormat,
  getTextHeaderVariables,
  hasMediaHeader,
  isValidPublicMediaUrl,
  requiresDynamicMediaUrl,
  shouldUseEnhancedTemplateFormat,
} from '../templateHelper';

describe('templateHelper media support', () => {
  const mediaTemplate = {
    name: 'promo_banner',
    components: [
      {
        type: 'HEADER',
        format: 'IMAGE',
        example: { header_handle: ['4::abc'] },
      },
      { type: 'BODY', text: 'Olá {{1}}' },
    ],
  };

  const textTemplate = {
    name: 'hello',
    components: [{ type: 'BODY', text: 'Olá {{1}}' }],
  };

  describe('requiresDynamicMediaUrl', () => {
    it('requires a media url for any IMAGE/VIDEO/DOCUMENT header', () => {
      expect(requiresDynamicMediaUrl(mediaTemplate)).toBe(true);
    });

    it('returns false for text-only templates', () => {
      expect(requiresDynamicMediaUrl(textTemplate)).toBe(false);
    });
  });

  describe('getHeaderMediaBadgeLabel', () => {
    it('labels media templates with format only', () => {
      expect(getHeaderMediaBadgeLabel(mediaTemplate)).toBe('IMAGE');
    });
  });

  describe('getHeaderMediaFormat', () => {
    it('returns IMAGE/VIDEO/DOCUMENT when header has media', () => {
      expect(getHeaderMediaFormat(mediaTemplate)).toBe('IMAGE');
      expect(
        getHeaderMediaFormat({
          components: [{ type: 'HEADER', format: 'document' }],
        })
      ).toBe('DOCUMENT');
    });

    it('returns null for text-only templates', () => {
      expect(getHeaderMediaFormat(textTemplate)).toBeNull();
    });
  });

  describe('isValidPublicMediaUrl', () => {
    it('accepts http and https urls', () => {
      expect(isValidPublicMediaUrl('https://cdn.example.com/a.jpg')).toBe(true);
      expect(isValidPublicMediaUrl('http://cdn.example.com/a.jpg')).toBe(true);
    });

    it('rejects invalid urls', () => {
      expect(isValidPublicMediaUrl('')).toBe(false);
      expect(isValidPublicMediaUrl('ftp://x.com/a.jpg')).toBe(false);
      expect(isValidPublicMediaUrl('not-a-url')).toBe(false);
    });
  });

  describe('shouldUseEnhancedTemplateFormat', () => {
    it('is true for media header templates', () => {
      expect(shouldUseEnhancedTemplateFormat(mediaTemplate)).toBe(true);
    });

    it('is true for text templates with body variables', () => {
      expect(shouldUseEnhancedTemplateFormat(textTemplate)).toBe(true);
    });

    it('is false for static templates without variables', () => {
      expect(
        shouldUseEnhancedTemplateFormat({
          components: [{ type: 'BODY', text: 'Hello' }],
        })
      ).toBe(false);
    });
  });

  describe('buildTemplateParameters', () => {
    it('includes header fields for media templates', () => {
      expect(buildTemplateParameters(mediaTemplate).header).toEqual({
        media_url: '',
        media_type: 'image',
      });
    });

    it('uses enhanced body structure for text templates', () => {
      expect(buildTemplateParameters(textTemplate)).toEqual({
        body: { '1': '' },
      });
    });
  });

  describe('allKeysRequired', () => {
    it('validates nested body and header media url', () => {
      expect(
        allKeysRequired({
          body: { '1': 'Maria' },
          header: {
            media_url: 'https://cdn.example.com/doc.pdf',
            media_type: 'document',
            media_name: 'doc.pdf',
          },
        })
      ).toBe(true);

      expect(
        allKeysRequired({
          body: { '1': '' },
          header: {
            media_url: 'https://cdn.example.com/doc.pdf',
            media_type: 'document',
          },
        })
      ).toBe(false);
    });
  });

  describe('hasMediaHeader', () => {
    it('detects media headers', () => {
      expect(hasMediaHeader(mediaTemplate)).toBe(true);
      expect(hasMediaHeader(textTemplate)).toBe(false);
    });
  });

  describe('getTextHeaderVariables', () => {
    it('returns variables from TEXT headers only', () => {
      expect(
        getTextHeaderVariables({
          components: [
            { type: 'HEADER', format: 'TEXT', text: 'Hello {{1}} and {{name}}' },
          ],
        })
      ).toEqual(['1', 'name']);
    });

    it('returns an empty list for media headers', () => {
      expect(getTextHeaderVariables(mediaTemplate)).toEqual([]);
    });
  });

  describe('buildTemplateParameters for NAMED templates', () => {
    it('preserves named body keys', () => {
      expect(
        buildTemplateParameters({
          parameter_format: 'NAMED',
          components: [
            {
              type: 'BODY',
              text: 'Hi {{first_name}}, order {{order_id}}',
            },
          ],
        })
      ).toEqual({
        body: {
          first_name: '',
          order_id: '',
        },
      });
    });

    it('includes named text header variables', () => {
      expect(
        buildTemplateParameters({
          parameter_format: 'NAMED',
          components: [
            {
              type: 'HEADER',
              format: 'TEXT',
              text: 'Welcome {{customer_name}}',
            },
            { type: 'BODY', text: 'Body copy' },
          ],
        })
      ).toEqual({
        header: { customer_name: '' },
      });
    });
  });
});
