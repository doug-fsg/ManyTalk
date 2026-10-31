import { MESSAGE_TYPE } from 'shared/constants/messages';
import {
  SPEAKER,
  attachmentFromTestBlock,
  bubbleClassForSpeaker,
  toApiHistory,
  toConversationMessage,
} from '../aiAttendantTestThread';

describe('aiAttendantTestThread', () => {
  it('places the tester on the right (outgoing) and the attendant on the left (incoming)', () => {
    const tester = toConversationMessage({
      id: 1,
      speaker: SPEAKER.TESTER,
      content: 'Oi',
      testerName: 'Cliente',
      attendantName: 'Lia',
    });
    const attendant = toConversationMessage({
      id: 2,
      speaker: SPEAKER.ATTENDANT,
      content: 'Olá',
      testerName: 'Cliente',
      attendantName: 'Lia',
    });

    expect(tester.message_type).toBe(MESSAGE_TYPE.OUTGOING);
    expect(attendant.message_type).toBe(MESSAGE_TYPE.INCOMING);
    expect(bubbleClassForSpeaker(SPEAKER.TESTER)).toBe('ia-test-msg--mine');
    expect(bubbleClassForSpeaker(SPEAKER.ATTENDANT)).toBe(
      'ia-test-msg--theirs'
    );
  });

  it('maps thread speakers to API history roles without using inbox sides', () => {
    const history = toApiHistory([
      toConversationMessage({
        id: 1,
        speaker: SPEAKER.TESTER,
        content: 'Oi',
        testerName: 'Cliente',
        attendantName: 'Lia',
      }),
      toConversationMessage({
        id: 2,
        speaker: SPEAKER.ATTENDANT,
        content: 'Olá',
        testerName: 'Cliente',
        attendantName: 'Lia',
      }),
    ]);

    expect(history).toEqual([
      { role: 'user', content: 'Oi' },
      { role: 'assistant', content: 'Olá' },
    ]);
  });

  it('keeps sandbox attachments in the thread and history as the file variable', () => {
    const attachment = attachmentFromTestBlock(
      {
        url: 'https://cdn.example/catalogo.png',
        filename: 'catalogo.png',
        file_type: 'image',
      },
      9
    );
    const message = toConversationMessage({
      id: 3,
      speaker: SPEAKER.ATTENDANT,
      content: '',
      historyContent: '{{anexo:catalogo}}',
      attachments: [attachment],
      testerName: 'Cliente',
      attendantName: 'Lia',
    });

    expect(message.attachments[0].data_url).toBe(
      'https://cdn.example/catalogo.png'
    );
    expect(toApiHistory([message])).toEqual([
      { role: 'assistant', content: '{{anexo:catalogo}}' },
    ]);
  });
});
