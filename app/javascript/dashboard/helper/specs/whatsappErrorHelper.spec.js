import { resolveWhatsappDeliveryError } from 'dashboard/helper/whatsappErrorHelper';

describe('whatsappErrorHelper', () => {
  const t = key => key;

  it('maps known WhatsApp error codes to i18n keys', () => {
    expect(
      resolveWhatsappDeliveryError(
        '131049: Esta mensagem não foi entregue para preservar a qualidade do ecossistema.',
        t
      )
    ).toBe('CONVERSATION.WHATSAPP_ERRORS.MARKETING_LIMIT');
  });

  it('returns humanized backend messages as-is', () => {
    expect(
      resolveWhatsappDeliveryError(
        'WhatsApp: limite de marketing da Meta atingido para este contato. Aguarde 24h antes de reenviar.',
        t
      )
    ).toBe(
      'WhatsApp: limite de marketing da Meta atingido para este contato. Aguarde 24h antes de reenviar.'
    );
  });
});
