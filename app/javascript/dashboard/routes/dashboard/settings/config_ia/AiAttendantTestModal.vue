<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'dashboard/composables/useI18n';
import AiAttendantAPI from 'dashboard/api/aiAttendant';
import Message from 'dashboard/components/widgets/conversation/Message.vue';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';
import {
  SPEAKER,
  attachmentFromTestBlock,
  bubbleClassForSpeaker,
  toApiHistory,
  toConversationMessage,
} from './aiAttendantTestThread';

const emit = defineEmits(['update:show', 'close']);

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  configId: {
    type: [Number, String],
    default: null,
  },
  agentName: {
    type: String,
    default: '',
  },
  inboxName: {
    type: String,
    default: '',
  },
  avatarUrl: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();

const draft = ref('');
const messages = ref([]);
const isTesting = ref(false);
const panelRef = ref(null);
let messageId = 0;

const nextMessageId = () => {
  messageId += 1;
  return messageId;
};

const displayAgentName = computed(
  () => props.agentName || t('AI_ATTENDANT.TEST.UNNAMED_AGENT')
);

const canSend = computed(
  () =>
    Boolean(props.configId) &&
    draft.value.trim().length > 0 &&
    !isTesting.value
);

const buildMessage = ({ speaker, content, attachments, historyContent }) =>
  toConversationMessage({
    id: nextMessageId(),
    speaker,
    content,
    attachments,
    historyContent,
    testerName: t('AI_ATTENDANT.TEST.CUSTOMER_LABEL'),
    attendantName: displayAgentName.value,
    attendantAvatarUrl: props.avatarUrl,
  });

const pushReplyBlocks = (reply, blocks) => {
  if (Array.isArray(blocks) && blocks.length) {
    blocks.forEach(block => {
      if (block.type === 'attachment' && block.url) {
        messages.value.push(
          buildMessage({
            speaker: SPEAKER.ATTENDANT,
            content: '',
            historyContent: block.token || block.filename,
            attachments: [attachmentFromTestBlock(block, nextMessageId())],
          })
        );
        return;
      }
      messages.value.push(
        buildMessage({
          speaker: SPEAKER.ATTENDANT,
          content: block.content || '',
        })
      );
    });
    return;
  }

  messages.value.push(
    buildMessage({
      speaker: SPEAKER.ATTENDANT,
      content: reply || t('AI_ATTENDANT.TEST.EMPTY'),
    })
  );
};

const resetConversation = () => {
  draft.value = '';
  messages.value = [];
  isTesting.value = false;
  messageId = 0;
};

watch(
  () => props.show,
  visible => {
    if (visible) resetConversation();
  }
);

const scrollToBottom = async () => {
  await nextTick();
  const panel = panelRef.value;
  if (panel) panel.scrollTop = panel.scrollHeight;
};

const handleClose = () => {
  emit('update:show', false);
  emit('close');
};

const historyForApi = () => toApiHistory(messages.value);

const sendMessage = async () => {
  const text = draft.value.trim();
  if (!text || !props.configId || isTesting.value) return;

  draft.value = '';
  messages.value.push(
    buildMessage({ speaker: SPEAKER.TESTER, content: text })
  );
  await scrollToBottom();

  isTesting.value = true;

  try {
    const priorHistory = historyForApi().slice(0, -1);
    const response = await AiAttendantAPI.test(
      props.configId,
      text,
      priorHistory
    );
    const { reply, handoff, messages: replyBlocks } = response.data || {};
    pushReplyBlocks(reply, replyBlocks);
    if (handoff) {
      messages.value.push(
        buildMessage({
          speaker: SPEAKER.EVENT,
          content: t('AI_ATTENDANT.TEST.HANDOFF_NOTICE'),
        })
      );
    }
  } catch (error) {
    useAlert(t('AI_ATTENDANT.TEST.ERROR_MESSAGE'));
    messages.value.push(
      buildMessage({
        speaker: SPEAKER.EVENT,
        content: t('AI_ATTENDANT.TEST.ERROR_MESSAGE'),
      })
    );
  } finally {
    isTesting.value = false;
    await scrollToBottom();
  }
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="handleClose">
    <div class="ia-test-chat flex flex-col w-full h-[36rem] max-h-[80vh]">
      <div
        class="flex items-center justify-between gap-3 px-4 py-2 pr-12 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
      >
        <div class="min-w-0">
          <p
            class="mb-0 text-base font-medium leading-tight text-slate-900 dark:text-slate-100 truncate"
          >
            {{ $t('AI_ATTENDANT.TEST.TITLE') }}
          </p>
          <p
            class="mb-0 text-xs text-slate-500 dark:text-slate-400 truncate"
          >
            {{ displayAgentName }} · {{ inboxName || '—' }}
          </p>
        </div>
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="tiny"
          icon="arrow-clockwise"
          :disabled="!messages.length"
          @click="resetConversation"
        >
          {{ $t('AI_ATTENDANT.TEST.RESET') }}
        </woot-button>
      </div>

      <div class="flex flex-col flex-grow min-h-0 bg-slate-25 dark:bg-slate-800">
        <ul ref="panelRef" class="conversation-panel">
          <li v-if="!messages.length" class="center">
            <div class="activity-wrap max-w-xs text-center">
              <span class="is-text">{{ $t('AI_ATTENDANT.TEST.HINT') }}</span>
            </div>
          </li>
          <Message
            v-for="message in messages"
            :key="message.id"
            :class="bubbleClassForSpeaker(message.speaker)"
            :data="message"
          />
        </ul>

        <div class="conversation-footer">
          <div
            v-if="isTesting"
            class="items-center flex h-0 absolute w-full -top-7"
          >
            <div
              class="flex py-2 pr-4 pl-5 shadow-md rounded-full bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-xs font-semibold my-2.5 mx-auto"
            >
              {{ $t('AI_ATTENDANT.TEST.RUNNING') }}
              <img
                class="ltr:ml-2 rtl:mr-2 w-6"
                src="~dashboard/assets/images/typing.gif"
                alt=""
              />
            </div>
          </div>
          <div class="reply-box">
            <div class="reply-box__top">
              <ResizableTextArea
                v-model="draft"
                class="input"
                :placeholder="$t('AI_ATTENDANT.TEST.PLACEHOLDER')"
                :min-height="4"
                :rows="1"
                :disabled="isTesting"
                @keydown.native.enter.exact.prevent="sendMessage"
              />
            </div>
            <div class="bottom-box">
              <div class="left-wrap" />
              <div class="right-wrap">
                <woot-button
                  size="small"
                  :is-disabled="!canSend"
                  :is-loading="isTesting"
                  @click="sendMessage"
                >
                  {{ $t('CONVERSATION.REPLYBOX.SEND') }}
                </woot-button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </woot-modal>
</template>

<style lang="scss">
.ia-test-chat {
  .conversation-panel {
    @apply h-auto flex-1;
  }

  .ia-test-msg--mine,
  .ia-test-msg--theirs {
    width: 100%;
  }

  .ia-test-msg--mine {
    justify-content: flex-end !important;

    .wrap {
      margin-left: auto;
      margin-right: 1rem;
    }
  }

  .ia-test-msg--theirs {
    justify-content: flex-start !important;

    .wrap {
      margin-right: auto;
      margin-left: 1rem;
    }
  }

  .context-menu-wrap {
    display: none;
  }

  .reply-box {
    @apply relative border-t border-slate-50 dark:border-slate-700 bg-white dark:bg-slate-900;
  }

  .reply-box__top {
    @apply relative py-0 px-4 -mt-px;

    textarea {
      @apply shadow-none border-transparent bg-transparent m-0 max-h-60 min-h-[3rem] pt-4 pb-0 px-0 resize-none;
    }
  }

  .bottom-box {
    @apply flex justify-between items-center py-3 px-4;
  }

  .right-wrap {
    @apply flex items-center;
  }
}
</style>
