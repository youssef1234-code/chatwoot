<template>
  <div class="p-3 bg-n-alpha-1 rounded-lg border border-n-weak">
    <!-- Message Header -->
    <div class="flex items-start justify-between mb-2">
      <div class="flex items-center gap-2">
        <!-- Sender Avatar -->
        <div class="w-6 h-6 rounded-full bg-n-alpha-2 flex items-center justify-center text-xs font-medium">
          {{ getSenderInitials(message.sender) }}
        </div>
        
        <!-- Sender Info -->
        <div>
          <p class="text-sm font-medium text-n-slate-12">
            {{ getSenderName(message.sender) }}
          </p>
          <p class="text-xs text-n-slate-9">
            {{ formatMessageTime(message.created_at) }}
          </p>
        </div>
      </div>

      <!-- Message Type Badge -->
      <span
        class="px-2 py-1 text-xs rounded-full"
        :class="getMessageTypeColor(message.message_type)"
      >
        {{ getMessageTypeLabel(message.message_type) }}
      </span>
    </div>

    <!-- Message Content -->
    <div class="text-sm text-n-slate-11">
      <div
        v-if="message.content_type === 'text'"
        class="whitespace-pre-wrap"
        :class="{ 'line-clamp-3': compact }"
      >
        {{ message.content }}
      </div>
      
      <div v-else-if="message.content_type === 'input_email'" class="italic">
        {{ $t('TICKETS.DETAIL.EMAIL_MESSAGE') }}
      </div>
      
      <div v-else-if="message.content_type === 'cards'" class="italic">
        {{ $t('TICKETS.DETAIL.CARD_MESSAGE') }}
      </div>
      
      <div v-else-if="message.content_type === 'input_select'" class="italic">
        {{ $t('TICKETS.DETAIL.SELECT_MESSAGE') }}
      </div>
      
      <div v-else class="italic">
        {{ $t('TICKETS.DETAIL.MEDIA_MESSAGE') }}
      </div>
    </div>

    <!-- Attachments -->
    <div v-if="message.attachments && message.attachments.length > 0" class="mt-2">
      <div class="flex items-center gap-2 text-xs text-n-slate-9">
        <Icon icon="i-lucide-paperclip" class="w-3 h-3" />
        <span>{{ message.attachments.length }} {{ $t('TICKETS.DETAIL.ATTACHMENTS') }}</span>
      </div>
    </div>

    <!-- Expand/Collapse for compact mode -->
    <div v-if="compact && isLongMessage" class="mt-2">
      <NextButton
        variant="ghost"
        size="xs"
        @click="expanded = !expanded"
      >
        {{ expanded ? $t('TICKETS.DETAIL.SHOW_LESS') : $t('TICKETS.DETAIL.SHOW_MORE') }}
      </NextButton>
    </div>
  </div>
</template>

<script>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatDistanceToNow, format } from 'date-fns';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

export default {
  name: 'MessageItem',
  components: {
    NextButton,
    Icon,
  },
  props: {
    message: {
      type: Object,
      required: true,
    },
    compact: {
      type: Boolean,
      default: false,
    },
  },
  setup(props) {
    const { t } = useI18n();
    
    // State
    const expanded = ref(false);

    // Computed
    const isLongMessage = computed(() => {
      return props.message.content && props.message.content.length > 200;
    });

    // Methods
    const getSenderName = (sender) => {
      if (!sender) return t('TICKETS.DETAIL.UNKNOWN_SENDER');
      return sender.name || sender.email || t('TICKETS.DETAIL.ANONYMOUS');
    };

    const getSenderInitials = (sender) => {
      if (!sender || !sender.name) return '??';
      return sender.name
        .split(' ')
        .map(word => word[0])
        .join('')
        .toUpperCase()
        .slice(0, 2);
    };

    const getMessageTypeLabel = (messageType) => {
      const types = {
        0: t('TICKETS.DETAIL.MESSAGE_TYPE.INCOMING'),
        1: t('TICKETS.DETAIL.MESSAGE_TYPE.OUTGOING'),
        2: t('TICKETS.DETAIL.MESSAGE_TYPE.ACTIVITY'),
        3: t('TICKETS.DETAIL.MESSAGE_TYPE.TEMPLATE'),
      };
      return types[messageType] || t('TICKETS.DETAIL.MESSAGE_TYPE.UNKNOWN');
    };

    const getMessageTypeColor = (messageType) => {
      const colors = {
        0: 'bg-blue-50 text-blue-700', // Incoming
        1: 'bg-green-50 text-green-700', // Outgoing
        2: 'bg-gray-50 text-gray-700', // Activity
        3: 'bg-purple-50 text-purple-700', // Template
      };
      return colors[messageType] || 'bg-gray-50 text-gray-700';
    };

    const formatMessageTime = (timestamp) => {
      if (!timestamp) return '';
      
      try {
        const date = new Date(timestamp);
        const now = new Date();
        const diffInHours = (now - date) / (1000 * 60 * 60);
        
        if (diffInHours < 24) {
          return formatDistanceToNow(date, { addSuffix: true });
        } else {
          return format(date, 'MMM dd, HH:mm');
        }
      } catch (error) {
        return timestamp;
      }
    };

    return {
      // State
      expanded,
      
      // Computed
      isLongMessage,
      
      // Methods
      getSenderName,
      getSenderInitials,
      getMessageTypeLabel,
      getMessageTypeColor,
      formatMessageTime,
    };
  },
};
</script>

<style scoped>
.line-clamp-3 {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
