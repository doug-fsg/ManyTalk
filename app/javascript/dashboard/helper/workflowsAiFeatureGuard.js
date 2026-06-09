import store from '../store';
import { FEATURE_FLAGS } from '../featureFlags';

export const AI_UPSELL_WHATSAPP_URL =
  'https://wa.me/555581051485?text=Ol%C3%A1!%20Gostaria%20de%20saber%20mais%20sobre%20o%20m%C3%B3dulo%20ManyTalks%20IA%20para%20atendimento%20autom%C3%A1tico%2024%2F7%20no%20WhatsApp.';

export const isAiFeatureEnabled = accountId => {
  const id = Number(accountId);
  if (!id) return false;

  return store.getters['accounts/isFeatureEnabledonAccount'](
    id,
    FEATURE_FLAGS.IA
  );
};

export const openAiUpsellWhatsApp = () => {
  window.open(AI_UPSELL_WHATSAPP_URL, '_blank', 'noopener,noreferrer');
};
