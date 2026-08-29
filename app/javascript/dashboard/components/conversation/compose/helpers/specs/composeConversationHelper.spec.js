import {
  buildFullPhoneNumber,
  buildQuickContactPayload,
  canQuickCreateContact,
  isPhoneQuery,
  normalizePhoneNumber,
} from '../composeConversationHelper';

describe('composeConversationHelper', () => {
  describe('isPhoneQuery', () => {
    it('detects phone-like input', () => {
      expect(isPhoneQuery('+5511999999999')).toBe(true);
      expect(isPhoneQuery('11999999999')).toBe(true);
      expect(isPhoneQuery('joao@email.com')).toBe(false);
    });
  });

  describe('canQuickCreateContact', () => {
    it('allows valid phone and email values', () => {
      expect(canQuickCreateContact('+5511999999999')).toBe(true);
      expect(canQuickCreateContact('11999999999')).toBe(true);
      expect(canQuickCreateContact('joao@email.com')).toBe(true);
      expect(canQuickCreateContact('jo')).toBe(false);
    });
  });

  describe('buildFullPhoneNumber', () => {
    it('combines dial code and local number', () => {
      expect(buildFullPhoneNumber('+55', '11999999999')).toBe('+5511999999999');
    });

    it('does not duplicate country code when local number already includes it', () => {
      expect(buildFullPhoneNumber('+55', '554299098450')).toBe('+554299098450');
    });

    it('uses international value when local starts with plus', () => {
      expect(buildFullPhoneNumber('+55', '+351912345678')).toBe('+351912345678');
    });

    it('preserves DDD 55 when it collides with country code 55', () => {
      expect(buildFullPhoneNumber('+55', '55991234567')).toBe('+5555991234567');
      expect(buildFullPhoneNumber('+55', '5599123456')).toBe('+555599123456');
    });
  });

  describe('buildQuickContactPayload', () => {
    it('builds phone payload with normalized number', () => {
      expect(buildQuickContactPayload('11999999999')).toEqual({
        name: '11999999999',
        phone_number: '+11999999999',
      });
    });

    it('builds email payload', () => {
      expect(buildQuickContactPayload('joao@email.com')).toEqual({
        name: 'Joao',
        email: 'joao@email.com',
      });
    });
  });

  describe('normalizePhoneNumber', () => {
    it('prefixes digits with plus sign', () => {
      expect(normalizePhoneNumber('5511999999999')).toBe('+5511999999999');
    });
  });
});
