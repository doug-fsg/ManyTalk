import {
  shouldBeUrl,
  isPhoneNumberValidWithDialCode,
  isPhoneE164OrEmpty,
  isPhoneE164,
  startsWithPlus,
  isValidPassword,
  isPhoneNumberValid,
  isNumber,
  isDomain,
  buildE164PhoneNumber,
  digitsIncludeDialCode,
} from '../Validators';

describe('#shouldBeUrl', () => {
  it('should return correct url', () => {
    expect(shouldBeUrl('http')).toEqual(true);
  });
  it('should return wrong url', () => {
    expect(shouldBeUrl('')).toEqual(true);
    expect(shouldBeUrl('abc')).toEqual(false);
  });
});

describe('#isPhoneE164', () => {
  it('should return correct phone number', () => {
    expect(isPhoneE164('+1234567890')).toEqual(true);
  });
  it('should return wrong phone number', () => {
    expect(isPhoneE164('1234567890')).toEqual(false);
    expect(isPhoneE164('12345678A9')).toEqual(false);
    expect(isPhoneE164('+12345678901234567890')).toEqual(false);
  });
});

describe('#isPhoneE164OrEmpty', () => {
  it('should return correct phone number', () => {
    expect(isPhoneE164OrEmpty('+1234567890')).toEqual(true);
    expect(isPhoneE164OrEmpty('')).toEqual(true);
  });
  it('should return wrong phone number', () => {
    expect(isPhoneE164OrEmpty('1234567890')).toEqual(false);
    expect(isPhoneE164OrEmpty('12345678A9')).toEqual(false);
    expect(isPhoneE164OrEmpty('+12345678901234567890')).toEqual(false);
  });
});

describe('#isPhoneNumberValid', () => {
  it('should return correct phone number', () => {
    expect(isPhoneNumberValid('1234567890', '+91')).toEqual(true);
  });
  it('should return wrong phone number', () => {
    expect(isPhoneNumberValid('12345A67890', '+1')).toEqual(false);
    expect(isPhoneNumberValid('12345A6789120', '+1')).toEqual(false);
  });
});

describe('#buildE164PhoneNumber', () => {
  it('combines dial code and local number', () => {
    expect(buildE164PhoneNumber('+55', '42999098450')).toBe('+5542999098450');
    expect(buildE164PhoneNumber('+1', '4155551234')).toBe('+14155551234');
  });

  it('does not duplicate country code when local number already includes it', () => {
    expect(buildE164PhoneNumber('+55', '554299098450')).toBe('+554299098450');
    expect(buildE164PhoneNumber('+1', '14155551234')).toBe('+14155551234');
    expect(buildE164PhoneNumber('+351', '351912345678')).toBe('+351912345678');
  });

  it('uses international value when local starts with plus', () => {
    expect(buildE164PhoneNumber('+55', '+351912345678')).toBe('+351912345678');
  });

  it('does not strip DDD 55 when local number starts with 55', () => {
    expect(buildE164PhoneNumber('+55', '55991234567')).toBe('+5555991234567');
    expect(buildE164PhoneNumber('+55', '5599123456')).toBe('+555599123456');
    expect(buildE164PhoneNumber('+55', '55')).toBe('+5555');
  });

  it('still treats pasted full BR international numbers as complete', () => {
    expect(buildE164PhoneNumber('+55', '5555991234567')).toBe('+5555991234567');
    expect(buildE164PhoneNumber('+55', '554299098450')).toBe('+554299098450');
  });
});

describe('#digitsIncludeDialCode', () => {
  it('distinguishes BR country code from DDD 55', () => {
    expect(digitsIncludeDialCode('+55', '55991234567')).toBe(false);
    expect(digitsIncludeDialCode('+55', '554299098450')).toBe(true);
    expect(digitsIncludeDialCode('+55', '5555991234567')).toBe(true);
  });

  it('keeps non-BR prefix behavior', () => {
    expect(digitsIncludeDialCode('+1', '14155551234')).toBe(true);
  });
});

describe('#isValidPassword', () => {
  it('should return correct password', () => {
    expect(isValidPassword('testPass4!')).toEqual(true);
    expect(isValidPassword('testPass4-')).toEqual(true);
    expect(isValidPassword('testPass4\\')).toEqual(true);
    expect(isValidPassword("testPass4'")).toEqual(true);
  });

  it('should return wrong password', () => {
    expect(isValidPassword('testpass4')).toEqual(false);
    expect(isValidPassword('testPass4')).toEqual(false);
    expect(isValidPassword('testpass4!')).toEqual(false);
    expect(isValidPassword('testPass!')).toEqual(false);
  });
});

describe('#isNumber', () => {
  it('should return correct number', () => {
    expect(isNumber('123')).toEqual(true);
  });

  it('should return wrong number', () => {
    expect(isNumber('123-')).toEqual(false);
    expect(isNumber('123./')).toEqual(false);
    expect(isNumber('string')).toEqual(false);
  });
});

describe('#isDomain', () => {
  it('should return correct domain', () => {
    expect(isDomain('test.com')).toEqual(true);
    expect(isDomain('www.test.com')).toEqual(true);
  });

  it('should return wrong domain', () => {
    expect(isDomain('test')).toEqual(false);
    expect(isDomain('test.')).toEqual(false);
    expect(isDomain('test.123')).toEqual(false);
    expect(isDomain('http://www.test.com')).toEqual(false);
    expect(isDomain('https://test.in')).toEqual(false);
  });
});

describe('#isPhoneNumberValidWithDialCode', () => {
  it('should return correct phone number', () => {
    expect(isPhoneNumberValidWithDialCode('+123456789')).toEqual(true);
    expect(isPhoneNumberValidWithDialCode('+12345')).toEqual(true);
  });
  it('should return wrong phone number', () => {
    expect(isPhoneNumberValidWithDialCode('+123')).toEqual(false);
    expect(isPhoneNumberValidWithDialCode('+1234')).toEqual(false);
  });
});

describe('#startsWithPlus', () => {
  it('should return correct phone number', () => {
    expect(startsWithPlus('+123456789')).toEqual(true);
  });
  it('should return wrong phone number', () => {
    expect(startsWithPlus('123456789')).toEqual(false);
  });
});
