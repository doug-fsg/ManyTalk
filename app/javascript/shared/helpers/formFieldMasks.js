import { getFieldKind } from './formFieldHelpers';

export const formatPhoneMask = value => {
  const digits = String(value || '').replace(/\D/g, '').slice(0, 11);
  if (!digits) return '';
  if (digits.length <= 2) return `(${digits}`;
  if (digits.length <= 6) return `(${digits.slice(0, 2)}) ${digits.slice(2)}`;
  if (digits.length <= 10) {
    return `(${digits.slice(0, 2)}) ${digits.slice(2, 6)}-${digits.slice(6)}`;
  }
  return `(${digits.slice(0, 2)}) ${digits.slice(2, 7)}-${digits.slice(7)}`;
};

export const formatCurrencyMask = value => {
  const digits = String(value || '').replace(/\D/g, '');
  if (!digits) return '';

  const padded = digits.padStart(3, '0');
  const cents = padded.slice(-2);
  const whole = padded.slice(0, -2).replace(/^0+(?=\d)/, '') || '0';
  const formattedWhole = whole.replace(/\B(?=(\d{3})+(?!\d))/g, '.');

  return `${formattedWhole},${cents}`;
};

export const formatPercentMask = value => {
  const cleaned = String(value || '')
    .replace(/[^\d,]/g, '')
    .replace(/,+/g, ',');
  if (!cleaned) return '';

  const [whole, ...rest] = cleaned.split(',');
  const fraction = rest.join('').slice(0, 2);
  return fraction ? `${whole},${fraction}` : whole;
};

export const formatNumberMask = value => {
  const cleaned = String(value || '').replace(/[^\d-]/g, '');
  if (!cleaned || cleaned === '-') return cleaned === '-' ? '' : cleaned;
  return cleaned.replace(/(?!^)-/g, '');
};

export const applyFieldInputMask = (field, value) => {
  switch (getFieldKind(field)) {
    case 'phone':
      return formatPhoneMask(value);
    case 'currency':
      return formatCurrencyMask(value);
    case 'percent':
      return formatPercentMask(value);
    case 'number':
      return formatNumberMask(value);
    default:
      return value;
  }
};

export const unmaskCurrencyValue = value => {
  const cleaned = String(value || '')
    .replace(/\./g, '')
    .replace(',', '.')
    .trim();
  if (!cleaned) return '';
  const num = Number(cleaned);
  return Number.isNaN(num) ? cleaned : String(num);
};

export const unmaskPercentValue = value => {
  const cleaned = String(value || '').replace(',', '.').trim();
  if (!cleaned) return '';
  const num = Number(cleaned);
  return Number.isNaN(num) ? cleaned : String(num);
};

export const normalizeFieldValueForSubmit = (field, value) => {
  if (value === null || value === undefined) return '';
  if (typeof value === 'boolean') return value ? 'true' : '';

  const str = String(value).trim();
  if (!str) return '';

  switch (getFieldKind(field)) {
    case 'currency':
      return unmaskCurrencyValue(str);
    case 'percent':
      return unmaskPercentValue(str);
    case 'number':
      return str.replace(/[^\d-]/g, '');
    default:
      return str;
  }
};
