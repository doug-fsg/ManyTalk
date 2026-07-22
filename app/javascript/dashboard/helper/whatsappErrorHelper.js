const WHATSAPP_ERROR_I18N_KEYS = {
  131037: 'CONVERSATION.WHATSAPP_ERRORS.DISPLAY_NAME_NOT_APPROVED',
  131049: 'CONVERSATION.WHATSAPP_ERRORS.MARKETING_LIMIT',
};

export function resolveWhatsappDeliveryError(externalError, t) {
  if (!externalError) return '';

  const match = externalError.match(/^(\d+):\s*(.+)$/s);
  if (match) {
    const i18nKey = WHATSAPP_ERROR_I18N_KEYS[match[1]];
    if (i18nKey) return t(i18nKey);
  }

  return externalError;
}
