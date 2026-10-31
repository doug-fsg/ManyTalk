import {
  isValidTokenKey,
  slugFromName,
  tokenFor,
  tokenFromFilename,
  tokenStatus,
} from '../aiAttendantReferenceVariables';

describe('aiAttendantReferenceVariables', () => {
  it('builds {{anexo:key}} from the filename', () => {
    expect(tokenFor('catalogo')).toBe('{{anexo:catalogo}}');
    expect(tokenFromFilename('Catálogo.pdf').token).toBe('{{anexo:catalogo}}');
    expect(tokenFromFilename('IMG_5612.jpg').token).toBe('{{anexo:img_5612}}');
  });

  it('uniquifies colliding slugs', () => {
    const first = tokenFromFilename('catalogo.png');
    const second = tokenFromFilename('catalogo.pdf', [first.key]);

    expect(second.token).toBe('{{anexo:catalogo-2}}');
  });

  it('keeps a short user name and rejects empty or too long keys', () => {
    expect(slugFromName('Catálogo 2024')).toBe('catalogo-2024');
    expect(isValidTokenKey('catalogo')).toBe(true);
    expect(isValidTokenKey('a')).toBe(false);
    expect(isValidTokenKey('5895c30be7bce75cc5318a08')).toBe(true);
  });

  it('marks typed variables as linked or missing', () => {
    const files = [{ tokenKey: 'catalogo', filename: 'catalogo.png' }];

    expect(tokenStatus('envie {{anexo:catalogo}} e {{anexo:foo}}', files)).toEqual(
      [
        {
          token: '{{anexo:catalogo}}',
          key: 'catalogo',
          linked: true,
          filename: 'catalogo.png',
        },
        {
          token: '{{anexo:foo}}',
          key: 'foo',
          linked: false,
          filename: '',
        },
      ]
    );
  });
});
