import { validatePhoneNumber, cleanPhoneNumber } from 'dashboard/routes/dashboard/settings/campaigns/utils/phoneValidation';

export function isWhatsappWebInbox(inbox) {
  if (!inbox || inbox.channel_type !== 'Channel::Api') return false;
  const attrs =
    inbox.channel?.additional_attributes ||
    inbox.additional_attributes ||
    {};
  return attrs.source === 'whatsapp_web';
}

export function isExternalWhatsappInbox(inbox) {
  return inbox?.channel_type === 'Channel::Whatsapp' || isWhatsappWebInbox(inbox);
}

export function listExternalWhatsappInboxes(inboxes = []) {
  return inboxes.filter(isExternalWhatsappInbox);
}

export function validateExternalWhatsappPhone(phone) {
  return validatePhoneNumber(phone);
}

export function normalizeExternalWhatsappPhone(phone) {
  if (!phone) return '';
  const cleaned = cleanPhoneNumber(phone);
  if (!cleaned) return '';

  if (phone.toString().trim().startsWith('+')) {
    return `+${cleaned}`;
  }

  if (cleaned.length === 10 || cleaned.length === 11) {
    const ddd = cleaned.slice(0, 2);
    const numberPart = cleaned.slice(2);
    const last8 = numberPart.slice(-8);
    if (parseInt(ddd, 10) < 31) {
      return `+55${ddd}9${last8}`;
    }
    return `+55${ddd}${last8}`;
  }

  if (cleaned.length >= 12 && cleaned.startsWith('55')) {
    return `+${cleaned}`;
  }

  return `+${cleaned}`;
}
