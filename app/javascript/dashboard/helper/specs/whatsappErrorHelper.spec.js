import {
  isWhatsappChannelDisconnectError,
  resolveWhatsappDeliveryError,
} from 'dashboard/helper/whatsappErrorHelper';

describe('whatsappErrorHelper', () => {
  const t = key => key;

  it('maps known WhatsApp error codes to i18n keys', () => {
    expect(
      resolveWhatsappDeliveryError(
        '131049: Esta mensagem não foi entregue para preservar a qualidade do ecossistema.',
        t
      )
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.MARKETING_LIMIT');

    expect(
      resolveWhatsappDeliveryError('131053: Media upload error', t)
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.MEDIA_FORMAT_NOT_SUPPORTED');

    expect(
      resolveWhatsappDeliveryError(
        '131042: Business eligibility payment issue',
        t
      )
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.PAYMENT_ISSUE');

    expect(
      resolveWhatsappDeliveryError(
        '133010: (#133010) Account not registered',
        t
      )
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.CHANNEL_DISCONNECTED');
  });

  it('maps known English Meta phrases to i18n keys', () => {
    expect(
      resolveWhatsappDeliveryError(
        'WhatsApp: Meta marketing limit reached for this contact. Wait 24h before resending.',
        t
      )
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.MARKETING_LIMIT');

    expect(
      resolveWhatsappDeliveryError('131053: Media upload error', t)
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.MEDIA_FORMAT_NOT_SUPPORTED');
  });

  it('returns humanized backend messages as-is when unknown', () => {
    expect(
      resolveWhatsappDeliveryError('999: Unknown provider error', t)
    ).toBe('999: Unknown provider error');
  });

  it('detects channel disconnect errors for reconnect CTA', () => {
    expect(
      isWhatsappChannelDisconnectError('133010: (#133010) Account not registered')
    ).toBe(true);
    expect(
      isWhatsappChannelDisconnectError(
        'WhatsApp inbox is disconnected. An administrator must reconnect it in inbox settings.'
      )
    ).toBe(true);
    expect(isWhatsappChannelDisconnectError('131049: marketing limit')).toBe(
      false
    );
  });
});

describe('whatsappErrorHelper', () => {
  const t = key => key;

  it('maps known WhatsApp error codes to i18n keys', () => {
    expect(
      resolveWhatsappDeliveryError(
        '131049: Esta mensagem não foi entregue para preservar a qualidade do ecossistema.',
        t
      )
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.MARKETING_LIMIT');

    expect(
      resolveWhatsappDeliveryError('131053: Media upload error', t)
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.MEDIA_FORMAT_NOT_SUPPORTED');

    expect(
      resolveWhatsappDeliveryError(
        '131042: Business eligibility payment issue',
        t
      )
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.PAYMENT_ISSUE');
  });

  it('maps known English Meta phrases to i18n keys', () => {
    expect(
      resolveWhatsappDeliveryError(
        'WhatsApp: Meta marketing limit reached for this contact. Wait 24h before resending.',
        t
      )
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.MARKETING_LIMIT');

    expect(
      resolveWhatsappDeliveryError('131053: Media upload error', t)
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.MEDIA_FORMAT_NOT_SUPPORTED');
  });

  it('returns humanized backend messages as-is when unknown', () => {
    expect(
      resolveWhatsappDeliveryError('999: Unknown provider error', t)
    ).toBe('999: Unknown provider error');
  });
});
