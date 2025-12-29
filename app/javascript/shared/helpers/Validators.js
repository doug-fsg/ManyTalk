export const isPhoneE164 = value => !!value.match(/^\+[1-9]\d{1,14}$/);

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
