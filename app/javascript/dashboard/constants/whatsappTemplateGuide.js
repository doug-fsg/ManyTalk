export const WHATSAPP_META_TEMPLATES_URL =
  'https://business.facebook.com/latest/whatsapp_manager/message_templates';

export const buildWhatsAppTemplatesUrl = wabaId => {
  if (!wabaId) {
    return WHATSAPP_META_TEMPLATES_URL;
  }

  return `https://business.facebook.com/wa/manage/message-templates/?waba_id=${encodeURIComponent(
    wabaId
  )}`;
};

export const getInboxWabaId = inbox => {
  return (
    inbox?.whatsapp_business_account_id ||
    inbox?.provider_config?.business_account_id ||
    null
  );
};

export const buildWhatsAppBillingUrl = wabaId => {
  if (!wabaId) {
    return 'https://business.facebook.com/billing_hub/accounts';
  }

  const params = new URLSearchParams({
    account_type: 'whatsapp-business-account',
    asset_id: String(wabaId),
  });

  return `https://business.facebook.com/billing_hub/accounts?${params.toString()}`;
};
