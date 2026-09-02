import AnalyticsHelper from './AnalyticsHelper';
import DashboardAudioNotificationHelper from './AudioAlerts/DashboardAudioNotificationHelper';
import { emitter } from 'shared/helpers/mitt';

export const CHATWOOT_SET_USER = 'CHATWOOT_SET_USER';
export const CHATWOOT_RESET = 'CHATWOOT_RESET';

export const ANALYTICS_IDENTITY = 'ANALYTICS_IDENTITY';
export const ANALYTICS_RESET = 'ANALYTICS_RESET';

let pendingSupportUser = null;

export const initializeAnalyticsEvents = () => {
  emitter.on(ANALYTICS_IDENTITY, ({ user }) => {
    AnalyticsHelper.identify(user);
  });
};

const initializeAudioAlerts = user => {
  const { ui_settings: uiSettings } = user || {};
  const {
    always_play_audio_alert: alwaysPlayAudioAlert,
    enable_audio_alerts: audioAlertType,
    alert_if_unread_assigned_conversation_exist: alertIfUnreadConversationExist,
    notification_tone: audioAlertTone,
    // UI Settings can be undefined initally as we don't send the
    // entire payload for the user during the signup process.
  } = uiSettings || {};

  DashboardAudioNotificationHelper.setInstanceValues({
    currentUserId: user.id,
    audioAlertType: audioAlertType || 'none',
    audioAlertTone: audioAlertTone || 'ding',
    alwaysPlayAudioAlert: alwaysPlayAudioAlert || false,
    alertIfUnreadConversationExist: alertIfUnreadConversationExist || false,
  });
};

const identifySupportWidgetUser = user => {
  if (!window.$chatwoot || !user?.email) {
    return false;
  }

  const payload = {
    avatar_url: user.avatar_url,
    email: user.email,
    name: user.name,
  };

  // Only send HMAC when Super Admin has CHATWOOT_INBOX_HMAC_KEY configured.
  // Passing an empty hash with "hmac mandatory" creates unverified anonymous contacts.
  if (user.hmac_identifier) {
    payload.identifier_hash = user.hmac_identifier;
  }

  window.$chatwoot.setUser(user.email, payload);
  window.$chatwoot.setCustomAttributes({
    signedUpAt: user.created_at,
    account_id: user.account_id,
  });

  return true;
};

export const initializeChatwootEvents = () => {
  window.addEventListener('chatwoot:ready', () => {
    if (pendingSupportUser) {
      identifySupportWidgetUser(pendingSupportUser);
    }
  });

  emitter.on(CHATWOOT_RESET, () => {
    pendingSupportUser = null;
    if (window.$chatwoot) {
      window.$chatwoot.reset();
    }
  });

  emitter.on(CHATWOOT_SET_USER, ({ user }) => {
    pendingSupportUser = user;

    if (!identifySupportWidgetUser(user)) {
      // Widget script still loading — chatwoot:ready will retry.
    }

    initializeAudioAlerts(user);
  });
};
