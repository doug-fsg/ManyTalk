export const isPhoneE164 = value => !!value.match(/^\+[1-9]\d{1,14}$/);

export const cleanPhoneDigits = value => `${value || ''}`.replace(/\D/g, '');

export const BR_COUNTRY_CODE = '55';

// Brazilian DDD 55 (RS) collides with country code 55. Only treat a leading
// "55" as embedded country code when length matches full international form.
export const digitsIncludeDialCode = (dialCode, digits) => {
  const code = cleanPhoneDigits(dialCode);
  if (!code || !digits.startsWith(code)) {
    return false;
  }

  if (code === BR_COUNTRY_CODE) {
    return digits.length >= 12;
  }

  return true;
};

// Combines dial code and local number without duplicating the country code.
// Works for any country: +55 + 554299098450 => +554299098450
export const buildE164PhoneNumber = (dialCode, localNumber) => {
  const local = `${localNumber || ''}`.trim();

  if (local.startsWith('+')) {
    return local.replace(/\s/g, '');
  }

  const code = cleanPhoneDigits(dialCode);
  const digits = cleanPhoneDigits(local);

  if (!digits) {
    return '';
  }

  if (digitsIncludeDialCode(code, digits)) {
    return `+${digits}`;
  }

  return code ? `+${code}${digits}` : `+${digits}`;
};

export const isPhoneNumberValid = (value, dialCode) => {
  const number = value.replace(dialCode, '');
  return !!number.match(/^[0-9]{1,14}$/);
};

export const isPhoneE164OrEmpty = value => isPhoneE164(value) || value === '';

export const isPhoneNumberValidWithDialCode = value => {
  const number = value.replace(/^\+/, ''); // Remove the '+' sign
  return !!number.match(/^[1-9]\d{4,}$/); // Validate the phone number with minimum 5 digits
};

export const startsWithPlus = value => value.startsWith('+');

export const shouldBeUrl = (value = '') =>
  value ? value.startsWith('http') : true;

export const isValidPassword = value => {
  const containsUppercase = /[A-Z]/.test(value);
  const containsLowercase = /[a-z]/.test(value);
  const containsNumber = /[0-9]/.test(value);
  const containsSpecialCharacter = /[!@#$%^&*()_+\-=[\]{}|'"/\\.,`<>:;?~]/.test(
    value
  );
  return (
    containsUppercase &&
    containsLowercase &&
    containsNumber &&
    containsSpecialCharacter
  );
};

export const isNumber = value => /^\d+$/.test(value);

export const isDomain = value => {
  if (value !== '') {
    const domainRegex = /^([\p{L}0-9]+(-[\p{L}0-9]+)*\.)+[a-z]{2,}$/gmu;
    return domainRegex.test(value);
  }
  return true;
};

/**
 * Creates a RegExp object from a string representation of a regular expression.
 * @param {string} regexPatternValue - The string representation of the regex (e.g., '/pattern/flags').
 * @returns {RegExp} A RegExp object created from the input string.
 */
export const getRegexp = regexPatternValue => {
  let lastSlash = regexPatternValue.lastIndexOf('/');
  return new RegExp(
    regexPatternValue.slice(1, lastSlash),
    regexPatternValue.slice(lastSlash + 1)
  );
};
