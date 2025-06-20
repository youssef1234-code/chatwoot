<script setup>
import MessagePreview from 'dashboard/components/widgets/conversation/MessagePreview.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { dynamicTime } from 'shared/helpers/timeHelper';

// Also import the constant values in case the enum doesn't work
const MESSAGE_TYPES = {
  INCOMING: 0,
  OUTGOING: 1,
  ACTIVITY: 2,
  TEMPLATE: 3
};

const props = defineProps({
  message: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['dismiss']);

const getSenderName = (message) => {
  if (!message) return 'Unknown';
  
  // For incoming messages (customer messages)
  if (message.message_type === MESSAGE_TYPE.INCOMING || message.message_type === MESSAGE_TYPES.INCOMING) {
    // Try multiple sources for customer name
    if (message.sender?.name) return message.sender.name;
    if (message.sender?.email) return message.sender.email;
    if (message.sender?.phone_number) return message.sender.phone_number;
    if (message.sender?.identifier) return message.sender.identifier;
    return 'Customer';
  } 
  
  // For outgoing messages (agent messages)
  if (message.message_type === MESSAGE_TYPE.OUTGOING || message.message_type === MESSAGE_TYPES.OUTGOING) {
    return message.sender?.name || 'Agent';
  }
  
  // For template messages
  if (message.message_type === MESSAGE_TYPE.TEMPLATE || message.message_type === MESSAGE_TYPES.TEMPLATE) {
    return message.sender?.name || 'Agent';
  }
  
  return 'System';
};

const formatMessageTime = (timestamp) => {
  if (!timestamp) return '';
  
  // Convert to Unix timestamp if it's a regular timestamp
  const unixTime = timestamp > 10000000000 ? Math.floor(timestamp / 1000) : timestamp;
  return dynamicTime(unixTime);
};
</script>

<template>
  <div
    class="reply-editor bg-n-slate-9/10 rounded-md py-3 pl-3 pr-2 text-sm tracking-wide mt-2 flex flex-col gap-2 -mx-2 border-l-4 border-blue-500"
  >
    <div class="flex items-center gap-2">
      <fluent-icon class="flex-shrink-0 icon text-blue-500" icon="arrow-reply" size="16" />
      <div class="flex-grow text-xs text-slate-600 dark:text-slate-400">
        {{ $t('CONVERSATION.REPLYBOX.REPLYING_TO') }}
      </div>
      <Button
        v-tooltip="$t('CONVERSATION.REPLYBOX.DISMISS_REPLY')"
        ghost
        xs
        slate
        icon="i-lucide-x"
        @click.stop="emit('dismiss')"
      />
    </div>
    
    <div class="reply-preview bg-slate-50 dark:bg-slate-800 rounded-md p-2 border border-slate-200 dark:border-slate-700">
      <div v-if="message" class="text-xs text-slate-500 dark:text-slate-400 mb-1">
        <span class="font-medium">{{ getSenderName(message) }}</span>
        <span class="ml-2">{{ formatMessageTime(message.created_at) }}</span>
      </div>
      <div class="text-sm text-slate-700 dark:text-slate-300">
        <MessagePreview
          v-if="message"
          :message="message"
          :show-message-type="false"
          :default-empty-message="$t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND')"
          class="reply-content"
        />
        <div v-else class="text-slate-500 dark:text-slate-400 italic">
          {{ $t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND') }}
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss">
// TODO: Remove this
// override for dashboard/assets/scss/widgets/_reply-box.scss
.reply-editor {
  .icon {
    margin-right: 0px !important;
  }
}

.reply-content {
  max-height: 60px;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  
  // Style the message preview content
  .message-preview {
    display: inline;
  }
  
  // Ensure links and formatted text are visible
  a {
    color: #3b82f6;
    text-decoration: underline;
  }
  
  strong, b {
    font-weight: 600;
  }
  
  em, i {
    font-style: italic;
  }
  
  code {
    background-color: rgba(0, 0, 0, 0.1);
    padding: 2px 4px;
    border-radius: 3px;
    font-family: monospace;
  }
}
</style>
