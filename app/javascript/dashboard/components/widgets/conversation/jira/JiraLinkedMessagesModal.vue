<template>
  <Modal :show="true" @close="onClose">
    <div class="w-full max-w-4xl mx-auto">
      <div class="flex flex-col h-[700px]">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600">
          <div>
            <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              Linked Messages
            </h2>
            <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
              Messages linked to {{ issueKey }}
            </p>
          </div>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-6">
          <!-- Loading State -->
          <div v-if="isLoading" class="flex items-center justify-center h-64">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
            <span class="ml-3 text-slate-600">Loading messages...</span>
          </div>

          <!-- Error State -->
          <div v-else-if="error" class="flex items-center justify-center h-64">
            <div class="text-center">
              <i class="ri-error-warning-line text-4xl text-red-500 mb-4" />
              <p class="text-red-600 mb-4">{{ error }}</p>
              <button
                class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
                @click="loadMessages"
              >
                Retry
              </button>
            </div>
          </div>

          <!-- Empty State -->
          <div v-else-if="messages.length === 0" class="flex items-center justify-center h-64">
            <div class="text-center">
              <i class="ri-message-3-line text-4xl text-slate-400 mb-4" />
              <p class="text-slate-600">No linked messages found</p>
            </div>
          </div>

          <!-- Messages List -->
          <div v-else class="space-y-4">
            <div
              v-for="message in messages"
              :key="message.id"
              class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-600 p-4 hover:shadow-sm transition-shadow"
            >
              <!-- Message Header -->
              <div class="flex items-center justify-between mb-3">
                <div class="flex items-center gap-3">
                  <!-- Sender Avatar -->
                  <div class="flex-shrink-0">
                    <div
                      v-if="getSenderName(message)"
                      class="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium"
                      :style="{ backgroundColor: getAvatarColor(getSenderName(message)) }"
                    >
                      {{ getInitials(getSenderName(message)) }}
                    </div>
                    <div
                      v-else
                      class="w-8 h-8 rounded-full bg-slate-400 flex items-center justify-center text-white text-sm"
                    >
                      <i class="ri-customer-service-2-line" />
                    </div>
                  </div>

                  <!-- Sender Info -->
                  <div>
                    <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                      {{ getSenderName(message) || 'System' }}
                    </p>
                    <p class="text-xs text-slate-500 dark:text-slate-400">
                      {{ formatDate(message.created_at) }}
                    </p>
                  </div>
                </div>

                <!-- Actions -->
                <div class="flex items-center gap-2">
                  <button
                    class="action-btn scroll-btn"
                    title="Scroll to message"
                    @click="scrollToMessage(message.id)"
                  >
                    <FluentIcon icon="chevron-up" size="16" />
                  </button>
                  <span
                    v-if="message.private"
                    class="px-2 py-1 text-xs font-medium bg-orange-100 text-orange-800 rounded-full"
                  >
                    Private
                  </span>
                  <span
                    class="px-2 py-1 text-xs font-medium rounded-full"
                    :class="getMessageTypeClass(message.message_type)"
                  >
                    {{ getMessageTypeLabel(message.message_type) }}
                  </span>
                </div>
              </div>

              <!-- Message Content -->
              <div class="prose prose-sm max-w-none dark:prose-invert">
                <div
                  v-if="message.content"
                  class="text-slate-700 dark:text-slate-300 whitespace-pre-wrap"
                  v-html="formatMessageContent(message.content)"
                />
                <div
                  v-else
                  class="text-slate-500 dark:text-slate-400 italic"
                >
                  [Attachment]
                </div>
              </div>

              <!-- Attachments -->
              <div v-if="message.attachments && message.attachments.length > 0" class="mt-3">
                <p class="text-xs text-slate-500 mb-2">Attachments:</p>
                <div class="grid grid-cols-2 md:grid-cols-3 gap-2">
                  <a
                    v-for="(attachment, idx) in message.attachments"
                    :key="idx"
                    :href="attachment.data_url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="block p-2 bg-slate-50 dark:bg-slate-700 rounded border hover:border-blue-400 transition-colors"
                  >
                    <!-- Image preview -->
                    <img
                      v-if="attachment.file_type === 'image' && attachment.data_url"
                      :src="attachment.data_url"
                      class="w-full h-24 object-cover rounded mb-1"
                      alt="Attachment"
                    />
                    <!-- Non-image file -->
                    <div
                      v-else
                      class="flex items-center gap-2"
                    >
                      <i
                        :class="getAttachmentIcon(attachment.file_type)"
                        class="text-lg text-slate-400"
                      />
                      <span class="text-xs text-blue-600 dark:text-blue-400 truncate">
                        {{ getAttachmentLabel(attachment.file_type) }}
                      </span>
                    </div>
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="flex justify-end gap-3 p-6 border-t border-slate-200 dark:border-slate-600">
          <button
            class="px-4 py-2 text-slate-600 border border-slate-300 rounded-md hover:bg-slate-50 transition-colors"
            @click="onClose"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  </Modal>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import Modal from 'dashboard/components/Modal.vue';
import JiraAPI from 'dashboard/api/integrations/jira';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';

const props = defineProps({
  issueKey: {
    type: String,
    required: true,
  },
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['close']);

const isLoading = ref(true);
const error = ref(null);
const messages = ref([]);

const loadMessages = async () => {
  isLoading.value = true;
  error.value = null;

  try {
    const response = await JiraAPI.getIssueMessages(
      props.conversationId,
      props.issueKey
    );
    messages.value = response.data || [];
  } catch (err) {
    console.error('Failed to load linked messages:', err);
    error.value = 'Failed to load messages. Please try again.';
  } finally {
    isLoading.value = false;
  }
};

const onClose = () => {
  emit('close');
};

const scrollToMessage = messageId => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, { messageId });
  onClose();
};

const getSenderName = message => {
  return message.sender_name || message.sender?.name || '';
};

const formatDate = dateString => {
  try {
    const d = new Date(dateString);
    return d.toLocaleString(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return dateString;
  }
};

const getInitials = name => {
  return name
    .split(' ')
    .map(word => word.charAt(0).toUpperCase())
    .slice(0, 2)
    .join('');
};

const getAvatarColor = name => {
  const colors = [
    '#6366f1',
    '#8b5cf6',
    '#ec4899',
    '#ef4444',
    '#f59e0b',
    '#10b981',
    '#06b6d4',
    '#84cc16',
  ];
  const hash = name
    .split('')
    .reduce((acc, char) => acc + char.charCodeAt(0), 0);
  return colors[hash % colors.length];
};

const getMessageTypeClass = messageType => {
  const type =
    messageType === 0
      ? 'incoming'
      : messageType === 1
        ? 'outgoing'
        : messageType === 2
          ? 'activity'
          : messageType;
  const classes = {
    incoming: 'bg-blue-100 text-blue-800',
    outgoing: 'bg-green-100 text-green-800',
    activity: 'bg-purple-100 text-purple-800',
    template: 'bg-yellow-100 text-yellow-800',
  };
  return classes[type] || 'bg-slate-100 text-slate-800';
};

const getMessageTypeLabel = messageType => {
  const labels = {
    0: 'Incoming',
    1: 'Outgoing',
    2: 'Activity',
    3: 'Template',
    incoming: 'Incoming',
    outgoing: 'Outgoing',
    activity: 'Activity',
    template: 'Template',
  };
  return labels[messageType] || String(messageType);
};

const getAttachmentIcon = fileType => {
  const icons = {
    image: 'ri-image-line',
    video: 'ri-video-line',
    audio: 'ri-music-line',
    file: 'ri-file-line',
  };
  return icons[fileType] || 'ri-attachment-line';
};

const getAttachmentLabel = fileType => {
  const labels = {
    image: 'Image',
    video: 'Video',
    audio: 'Audio',
    file: 'File',
  };
  return labels[fileType] || 'File';
};

const formatMessageContent = content => {
  if (!content) return '';
  // Basic sanitization - escape HTML first, then apply safe formatting
  const escaped = content
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  return escaped
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.*?)\*/g, '<em>$1</em>')
    .replace(/\n/g, '<br>');
};

onMounted(() => {
  loadMessages();
});
</script>

<style scoped lang="scss">
.action-btn {
  padding: 8px;
  border: none;
  background: transparent;
  border-radius: 6px;
  color: rgb(var(--color-ash-600));
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    background-color: rgb(var(--color-ash-100));
    color: rgb(var(--color-ash-800));
  }

  &.scroll-btn {
    color: rgb(var(--color-primary-600));

    &:hover {
      background-color: rgb(var(--color-primary-100));
      color: rgb(var(--color-primary-700));
    }
  }
}
</style>
