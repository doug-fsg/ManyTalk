import {
  humanizeAccountMode,
  humanizeMessagingLimitTier,
  humanizeNameStatus,
  humanizeQualityRating,
  humanizeVerificationStatus,
  isPartnerBillingError,
} from 'dashboard/helper/whatsappHealthLabels';

describe('whatsappHealthLabels', () => {
  const t = (key, params) => {
    if (params) return `${key}:${params.count || ''}`;
    return key;
  };

  it('humanizes meta health enum values', () => {
    expect(humanizeNameStatus('AVAILABLE_WITHOUT_REVIEW', t)).toBe(
      'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.NAME_STATUS.AVAILABLE_WITHOUT_REVIEW'
    );
    expect(humanizeVerificationStatus('NOT_VERIFIED', t)).toBe(
      'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.VERIFICATION.NOT_VERIFIED'
    );
    expect(humanizeQualityRating('GREEN', t)).toBe(
      'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.QUALITY.GREEN'
    );
    expect(humanizeMessagingLimitTier('TIER_250', t)).toBe(
      'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.MESSAGING_LIMIT.TIER:250'
    );
    expect(humanizeAccountMode('LIVE', t)).toBe(
      'INBOX_MGMT.ACCOUNT_HEALTH.VALUES.ACCOUNT_MODE.LIVE'
    );
  });

  it('detects partner billing errors', () => {
    expect(
      isPartnerBillingError(
        'Cost is not shown for businesses who bill through a partner',
        null
      )
    ).toBe(true);
    expect(isPartnerBillingError('', 'partner_billing')).toBe(true);
  });
});
