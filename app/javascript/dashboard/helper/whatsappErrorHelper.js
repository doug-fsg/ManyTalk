const WHATSAPP_ERROR_I18N_KEYS = {
  131037: 'CONVERSATION.WHATSAPP_ERRORS.DISPLAY_NAME_NOT_APPROVED',
  131042: 'CONVERSATION.WHATSAPP_ERRORS.PAYMENT_ISSUE',
  131049: 'CONVERSATION.WHATSAPP_ERRORS.MARKETING_LIMIT',
  131053: 'CONVERSATION.WHATSAPP_ERRORS.MEDIA_FORMAT_NOT_SUPPORTED',
  133010: 'CONVERSATION.WHATSAPP_ERRORS.CHANNEL_DISCONNECTED',
  190: 'CONVERSATION.WHATSAPP_ERRORS.CHANNEL_DISCONNECTED',
};

const CHANNEL_DISCONNECT_CODES = new Set(['133010', '190']);

const WHATSAPP_ERROR_PHRASE_PATTERNS = [
  {
    pattern: /marketing limit reached|limite de marketing/i,
    key: 'CONVERSATION.WHATSAPP_ERRORS.MARKETING_LIMIT',
  },
  {
    pattern:
      /payment method|payment issue|business eligibility payment|problema de pagamento/i,
    key: 'CONVERSATION.WHATSAPP_ERRORS.PAYMENT_ISSUE',
  },
  {
    pattern: /media upload error|unsupported format|formato não suportado/i,
    key: 'CONVERSATION.WHATSAPP_ERRORS.MEDIA_FORMAT_NOT_SUPPORTED',
  },
  {
    pattern: /display name pending|nome pendente/i,
    key: 'CONVERSATION.WHATSAPP_ERRORS.DISPLAY_NAME_NOT_APPROVED',
  },
  {
    pattern:
      /account not registered|missing permissions|inbox is disconnected|inbox whatsapp desconectado/i,
    key: 'CONVERSATION.WHATSAPP_ERRORS.CHANNEL_DISCONNECTED',
  },
];

export function resolveWhatsappDeliveryError(externalError, t) {
  if (!externalError) return '';

  const codeMatch = externalError.match(/^(\d+):\s*(.+)$/s);
  if (codeMatch) {
    const i18nKey = WHATSAPP_ERROR_I18N_KEYS[codeMatch[1]];
    if (i18nKey) return t(i18nKey);
  }

  const phraseMatch = WHATSAPP_ERROR_PHRASE_PATTERNS.find(({ pattern }) =>
    pattern.test(externalError)
  );
  if (phraseMatch) return t(phraseMatch.key);

  return externalError;
}

export function isWhatsappChannelDisconnectError(externalError) {
  if (!externalError) return false;

  const codeMatch = externalError.match(/^(\d+):/);
  if (codeMatch && CHANNEL_DISCONNECT_CODES.has(codeMatch[1])) return true;

  return WHATSAPP_ERROR_PHRASE_PATTERNS.some(
    ({ key, pattern }) =>
      key === 'CONVERSATION.WHATSAPP_ERRORS.CHANNEL_DISCONNECTED' &&
      pattern.test(externalError)
  );
}
