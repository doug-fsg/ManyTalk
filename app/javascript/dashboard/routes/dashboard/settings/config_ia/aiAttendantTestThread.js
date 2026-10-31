import { MESSAGE_STATUS, MESSAGE_TYPE } from 'shared/constants/messages';

export const SPEAKER = {
  TESTER: 'tester',
  ATTENDANT: 'attendant',
  EVENT: 'event',
};

const SPEAKER_TO_MESSAGE_TYPE = {
  [SPEAKER.TESTER]: MESSAGE_TYPE.OUTGOING,
  [SPEAKER.ATTENDANT]: MESSAGE_TYPE.INCOMING,
  [SPEAKER.EVENT]: MESSAGE_TYPE.ACTIVITY,
};

export const toConversationMessage = ({
  id,
  speaker,
  content,
  testerName,
  attendantName,
  attendantAvatarUrl = '',
  attachments = [],
  historyContent,
  createdAt = Math.floor(Date.now() / 1000),
  status = MESSAGE_STATUS.SENT,
}) => {
  const isTester = speaker === SPEAKER.TESTER;
  const isEvent = speaker === SPEAKER.EVENT;

  return {
    id,
    speaker,
    content,
    historyContent,
    message_type: SPEAKER_TO_MESSAGE_TYPE[speaker] ?? MESSAGE_TYPE.ACTIVITY,
    content_type: 'text',
    content_attributes: {},
    created_at: createdAt,
    status,
    private: false,
    source_id: isEvent ? null : `ia-test-${id}`,
    inbox_id: 0,
    sender: isTester
      ? { name: testerName, type: 'contact' }
      : {
          name: attendantName,
          type: 'user',
          thumbnail: attendantAvatarUrl,
          avatar_url: attendantAvatarUrl,
        },
    attachments,
  };
};

export const attachmentFromTestBlock = (block, id) => ({
  id,
  file_type: block.file_type || 'file',
  data_url: block.url,
  thumb_url: block.url,
  extension: (block.filename || '').split('.').pop(),
  fallback_title: block.filename,
});

export const historyContentFor = message => {
  if (message.historyContent) return message.historyContent;
  if (message.content) return message.content;
  const attachment = (message.attachments || [])[0];
  return attachment?.fallback_title || '';
};

export const toApiHistory = messages =>
  (messages || [])
    .filter(
      entry =>
        (entry.speaker === SPEAKER.TESTER ||
          entry.speaker === SPEAKER.ATTENDANT) &&
        entry.status !== MESSAGE_STATUS.PROGRESS
    )
    .map(entry => ({
      role: entry.speaker === SPEAKER.TESTER ? 'user' : 'assistant',
      content: historyContentFor(entry),
    }));

export const bubbleClassForSpeaker = speaker => {
  if (speaker === SPEAKER.TESTER) return 'ia-test-msg--mine';
  if (speaker === SPEAKER.ATTENDANT) return 'ia-test-msg--theirs';
  return '';
};
