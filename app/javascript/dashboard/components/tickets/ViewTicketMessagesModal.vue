<template>
  <Modal :show="true" @close="onClose">
    <div class="w-full max-w-4xl mx-auto">
      <div class="flex flex-col h-[700px]">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600">
          <div>
            <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              {{ $t('TICKETS.LINKED_MESSAGES.TITLE') }}
            </h2>
            <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
              {{ $t('TICKETS.LINKED_MESSAGES.SUBTITLE', { ticket: `#${ticket.id}` }) }}
            </p>
          </div>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-6">
          <!-- Loading State -->
          <div v-if="isLoading" class="flex items-center justify-center h-64">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span class="ml-3 text-slate-600">{{ $t('TICKETS.LINKED_MESSAGES.LOADING') }}</span>
          </div>

          <!-- Error State -->
          <div v-else-if="error" class="flex items-center justify-center h-64">
            <div class="text-center">
              <i class="ri-error-warning-line text-4xl text-red-500 mb-4"></i>
              <p class="text-red-600 mb-4">{{ error }}</p>
              <button
                class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
                @click="loadMessages"
              >
                {{ $t('TICKETS.LINKED_MESSAGES.RETRY') }}
              </button>
            </div>
          </div>

          <!-- Empty State -->
          <div v-else-if="messages.length === 0" class="flex items-center justify-center h-64">
            <div class="text-center">
              <i class="ri-message-3-line text-4xl text-slate-400 mb-4"></i>
              <p class="text-slate-600">{{ $t('TICKETS.LINKED_MESSAGES.NO_MESSAGES') }}</p>
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
                      v-if="message.sender"
                      class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white text-sm font-medium"
                      :style="{ backgroundColor: getAvatarColor(message.sender.name) }"
                    >
                      {{ getInitials(message.sender.name) }}
                    </div>
                    <div
                      v-else
                      class="w-8 h-8 rounded-full bg-slate-400 flex items-center justify-center text-white text-sm"
                    >
                      <i class="ri-customer-service-2-line"></i>
                    </div>
                  </div>

                  <!-- Sender Info -->
                  <div>
                    <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                      {{ message.sender ? message.sender.name : $t('TICKETS.LINKED_MESSAGES.SYSTEM') }}
                    </p>
                    <p class="text-xs text-slate-500 dark:text-slate-400">
                      {{ formatDate(message.created_at) }}
                    </p>
                  </div>
                </div>

                <!-- Message Type Badge -->
                <div class="flex items-center gap-2">
                  <span
                    v-if="message.private"
                    class="px-2 py-1 text-xs font-medium bg-orange-100 text-orange-800 rounded-full"
                  >
                    {{ $t('TICKETS.LINKED_MESSAGES.PRIVATE') }}
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
                  v-if="message.content_type === 'text'"
                  class="text-slate-700 dark:text-slate-300 whitespace-pre-wrap"
                  v-html="formatMessageContent(message.content)"
                ></div>
                <div
                  v-else
                  class="text-slate-500 dark:text-slate-400 italic"
                >
                  {{ $t('TICKETS.LINKED_MESSAGES.NON_TEXT_MESSAGE', { type: message.content_type }) }}
                </div>
              </div>

              <!-- Attachments -->
              <div v-if="message.attachments && message.attachments.length > 0" class="mt-3">
                <p class="text-xs text-slate-500 mb-2">{{ $t('TICKETS.LINKED_MESSAGES.ATTACHMENTS') }}:</p>
                <div class="grid grid-cols-2 md:grid-cols-3 gap-2">
                  <div
                    v-for="attachment in message.attachments"
                    :key="attachment.id"
                    class="flex items-center gap-2 p-2 bg-slate-50 dark:bg-slate-700 rounded border"
                  >
                    <i class="ri-attachment-line text-slate-400"></i>
                    <span class="text-xs text-slate-600 dark:text-slate-300 truncate">
                      {{ attachment.file_type || 'File' }}
                    </span>
                  </div>
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
            {{ $t('TICKETS.LINKED_MESSAGES.CLOSE') }}
          </button>
        </div>
      </div>
    </div>
  </Modal>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import TicketsAPI from 'dashboard/api/tickets';
import { formatDate as formatDateHelper } from 'shared/helpers/DateHelper';

const props = defineProps({
  ticket: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const isLoading = ref(true);
const error = ref(null);
const messages = ref([]);

const loadMessages = async () => {
  isLoading.value = true;
  error.value = null;

  try {
    const response = await TicketsAPI.getMessages(props.ticket.id);
    messages.value = response.data.messages || [];
  } catch (err) {
    console.error('Failed to load ticket messages:', err);
    error.value = t('TICKETS.LINKED_MESSAGES.LOAD_ERROR');
    useAlert(t('TICKETS.LINKED_MESSAGES.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const onClose = () => {
  emit('close');
};

const formatDate = (dateString) => {
  try {
    return formatDateHelper(new Date(dateString), 'MMM dd, yyyy h:mm a');
  } catch {
    return dateString;
  }
};

const getInitials = (name) => {
  return name
    .split(' ')
    .map(word => word.charAt(0).toUpperCase())
    .slice(0, 2)
    .join('');
};

const getAvatarColor = (name) => {
  const colors = [
    '#6366f1', '#8b5cf6', '#ec4899', '#ef4444',
    '#f59e0b', '#10b981', '#06b6d4', '#84cc16'
  ];
  const hash = name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
  return colors[hash % colors.length];
};

const getMessageTypeClass = (messageType) => {
  const classes = {
    incoming: 'bg-blue-100 text-blue-800',
    outgoing: 'bg-green-100 text-green-800',
    activity: 'bg-purple-100 text-purple-800',
    template: 'bg-yellow-100 text-yellow-800',
  };
  return classes[messageType] || 'bg-slate-100 text-slate-800';
};

const getMessageTypeLabel = (messageType) => {
  const labels = {
    incoming: t('TICKETS.LINKED_MESSAGES.TYPE.INCOMING'),
    outgoing: t('TICKETS.LINKED_MESSAGES.TYPE.OUTGOING'),
    activity: t('TICKETS.LINKED_MESSAGES.TYPE.ACTIVITY'),
    template: t('TICKETS.LINKED_MESSAGES.TYPE.TEMPLATE'),
  };
  return labels[messageType] || messageType;
};

const formatMessageContent = (content) => {
  if (!content) return '';
  
  // Basic markdown-like formatting
  return content
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.*?)\*/g, '<em>$1</em>')
    .replace(/\n/g, '<br>');
};

onMounted(() => {
  loadMessages();
});
</script>

<style scoped>
.prose {
  max-width: none;
}
</style>
