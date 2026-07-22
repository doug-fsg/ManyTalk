import ContactAPI from 'dashboard/api/contacts';
import { cleanPhoneNumber } from 'dashboard/routes/dashboard/settings/campaigns/utils/phoneValidation';

export const MIN_TEXT_SEARCH_LENGTH = 2;
export const MIN_PHONE_SEARCH_LENGTH = 3;

export const buildFullPhoneNumber = (dialCode, localNumber) => {
  const local = `${localNumber || ''}`.trim();

  if (local.startsWith('+')) {
    return normalizePhoneNumber(local);
  }

  const code = cleanPhoneNumber(dialCode);
  const digits = cleanPhoneNumber(local);

  if (!digits) {
    return '';
  }

  return `+${code}${digits}`;
};

export const getCapitalizedNameFromEmail = email => {
  const name = email.match(/^([^@]*)@/)?.[1] || email.split('@')[0];
  return name.charAt(0).toUpperCase() + name.slice(1);
};

export const isPhoneQuery = query => {
  const trimmed = query.trim();
  if (!trimmed) return false;
  if (trimmed.startsWith('+')) return true;
  return /^[\d\s()-]+$/.test(trimmed);
};

export const isEmailQuery = query => query.trim().includes('@');

export const normalizePhoneNumber = query => {
  const trimmed = query.trim();
  if (trimmed.startsWith('+')) {
    return trimmed.replace(/\s/g, '');
  }

  const digits = cleanPhoneNumber(trimmed);
  if (!digits) return '';

  return `+${digits}`;
};

export const canQuickCreateContact = query => {
  const trimmed = query.trim();
  if (!trimmed) return false;

  if (isEmailQuery(trimmed)) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed);
  }

  if (isPhoneQuery(trimmed)) {
    const digits = cleanPhoneNumber(trimmed);
    return digits.length >= 8;
  }

  return false;
};

export const buildQuickContactPayload = query => {
  const trimmed = query.trim();
  if (!trimmed || !canQuickCreateContact(trimmed)) {
    return null;
  }

  if (isEmailQuery(trimmed)) {
    return {
      name: getCapitalizedNameFromEmail(trimmed),
      email: trimmed,
    };
  }

  const phoneNumber = normalizePhoneNumber(trimmed);
  const digits = cleanPhoneNumber(phoneNumber);

  return {
    name: digits,
    phone_number: phoneNumber,
  };
};

export const getMinSearchLength = query => {
  if (isPhoneQuery(query)) {
    return MIN_PHONE_SEARCH_LENGTH;
  }

  return MIN_TEXT_SEARCH_LENGTH;
};

export const normalizeSearchQuery = query => {
  let value = query.trim();
  if (value && value.charAt(0) === '+') {
    value = value.substring(1);
  }
  return value;
};

export const searchContacts = async (query, page = 1) => {
  const value = normalizeSearchQuery(query);
  const minLength = getMinSearchLength(query);

  if (value.length < minLength) {
    return [];
  }

  const response = await ContactAPI.search(
    encodeURIComponent(value),
    page,
    'name'
  );

  return response.data.payload || [];
};

export const createQuickContact = async query => {
  const payload = buildQuickContactPayload(query);
  if (!payload) {
    throw new Error('Invalid contact input');
  }

  const response = await ContactAPI.create(payload);
  return response.data.payload.contact;
};

export const contactDisplayLabel = contact => {
  if (contact.email) {
    return `${contact.name} (${contact.email})`;
  }
  if (contact.phone_number) {
    return `${contact.name} (${contact.phone_number})`;
  }
  return contact.name;
};

export const quickCreateLabel = query => {
  const trimmed = query.trim();
  if (isEmailQuery(trimmed)) {
    return trimmed;
  }

  return normalizePhoneNumber(trimmed);
};
