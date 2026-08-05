const NAME_STATUS_KEYS = {
  APPROVED: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.NAME_STATUS.APPROVED',
  AVAILABLE_WITHOUT_REVIEW:
    'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.NAME_STATUS.AVAILABLE_WITHOUT_REVIEW',
  DECLINED: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.NAME_STATUS.DECLINED',
  EXPIRED: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.NAME_STATUS.EXPIRED',
  PENDING_REVIEW: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.NAME_STATUS.PENDING_REVIEW',
  NONE: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.NAME_STATUS.NONE',
};

const VERIFICATION_STATUS_KEYS = {
  VERIFIED: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.VERIFICATION.VERIFIED',
  NOT_VERIFIED: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.VERIFICATION.NOT_VERIFIED',
  EXPIRED: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.VERIFICATION.EXPIRED',
};

const QUALITY_KEYS = {
  GREEN: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.QUALITY.GREEN',
  YELLOW: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.QUALITY.YELLOW',
  RED: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.QUALITY.RED',
  UNKNOWN: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.QUALITY.UNKNOWN',
};

const ACCOUNT_MODE_KEYS = {
  LIVE: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.ACCOUNT_MODE.LIVE',
  SANDBOX: 'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.ACCOUNT_MODE.SANDBOX',
};

const PARTNER_BILLING_PATTERNS = [
  /cost is not shown for businesses who bill through a partner/i,
  /cost is not shown/i,
  /bill through a partner/i,
  /solution partner/i,
  /meta partner billing/i,
  /cobrança via parceiro meta/i,
  /custo indisponível via api/i,
  /cost unavailable via api/i,
];

export function isPartnerBillingError(errorMessage, errorCode) {
  if (errorCode === 'partner_billing') return true;
  if (!errorMessage) return false;

  return PARTNER_BILLING_PATTERNS.some(pattern => pattern.test(errorMessage));
}

export function humanizeNameStatus(value, t) {
  const key = NAME_STATUS_KEYS[value];
  return key ? t(key) : value || t('INBOX_MGMT.ACCOUNT_HEALTH.VALUES.UNKNOWN');
}

export function humanizeVerificationStatus(value, t) {
  const key = VERIFICATION_STATUS_KEYS[value];
  return key ? t(key) : value || t('INBOX_MGMT.ACCOUNT_HEALTH.VALUES.UNKNOWN');
}

export function humanizeQualityRating(value, t) {
  const key = QUALITY_KEYS[value] || QUALITY_KEYS.UNKNOWN;
  return t(key);
}

export function humanizeAccountMode(value, t) {
  const key = ACCOUNT_MODE_KEYS[value];
  return key ? t(key) : value || t('INBOX_MGMT.ACCOUNT_HEALTH.VALUES.UNKNOWN');
}

export function humanizeMessagingLimitTier(value, t) {
  if (!value) return '—';

  if (value === 'TIER_UNLIMITED') {
    return t('INBOX_MGMT.ACCOUNT_HEALTH.VALUES.MESSAGING_LIMIT.UNLIMITED');
  }

  const match = value.match(/^TIER_(\d+)$/);
  if (match) {
    return t('INBOX_MGMT.ACCOUNT_HEALTH.VALUES.MESSAGING_LIMIT.TIER', {
      count: match[1],
    });
  }

  return value;
}

export function resolvePricingErrorMessage(errorMessage, errorCode, t) {
  if (isPartnerBillingError(errorMessage, errorCode)) {
    return t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.PARTNER_BILLING.TITLE');
  }

  return (
    errorMessage || t('INBOX_MGMT.ACCOUNT_HEALTH.PRICING.LOAD_ERROR')
  );
}
