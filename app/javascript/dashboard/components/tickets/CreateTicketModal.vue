<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('TICKETS.CREATE_TICKET')"
      :header-content="$t('TICKETS.CREATE_TICKET_DESCRIPTION')"
    />

    <div class="flex flex-col px-8 pb-4 space-y-4">
      <!-- Title -->
      <label class="block">
        <span class="block text-sm font-medium text-slate-800 dark:text-slate-200 mb-1">
          {{ $t('TICKETS.TITLE') }} *
        </span>
        <input
          v-model="ticketForm.title"
          type="text"
          class="block w-full border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-700 dark:text-slate-200"
          :placeholder="$t('TICKETS.TITLE_PLACEHOLDER')"
          required
        />
        <p v-if="errors.title" class="mt-1 text-sm text-red-600">{{ errors.title[0] }}</p>
      </label>

      <!-- Description -->
      <label class="block">
        <span class="block text-sm font-medium text-slate-800 dark:text-slate-200 mb-1">
          {{ $t('TICKETS.DESCRIPTION') }}
        </span>
        <textarea
          v-model="ticketForm.description"
          rows="4"
          class="block w-full border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-700 dark:text-slate-200"
          :placeholder="$t('TICKETS.DESCRIPTION_PLACEHOLDER')"
        />
        <p v-if="errors.description" class="mt-1 text-sm text-red-600">{{ errors.description[0] }}</p>
      </label>

      <!-- Priority -->
      <label class="block">
        <span class="block text-sm font-medium text-slate-800 dark:text-slate-200 mb-1">
          {{ $t('TICKETS.PRIORITY') }}
        </span>
        <select
          v-model="ticketForm.priority"
          class="block w-full border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-700 dark:text-slate-200"
        >
          <option value="low">{{ $t('TICKETS.PRIORITY_LOW') }}</option>
          <option value="medium">{{ $t('TICKETS.PRIORITY_MEDIUM') }}</option>
          <option value="high">{{ $t('TICKETS.PRIORITY_HIGH') }}</option>
          <option value="urgent">{{ $t('TICKETS.PRIORITY_URGENT') }}</option>
        </select>
      </label>

      <!-- Issue Type -->
      <label class="block">
        <span class="block text-sm font-medium text-slate-800 dark:text-slate-200 mb-1">
          {{ $t('TICKETS.ISSUE_TYPE') }}
        </span>
        <input
          v-model="ticketForm.issue_type"
          type="text"
          class="block w-full border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-700 dark:text-slate-200"
          :placeholder="$t('TICKETS.ISSUE_TYPE_PLACEHOLDER')"
        />
      </label>

      <!-- Link to JIRA Issue -->
      <label class="block">
        <span class="block text-sm font-medium text-slate-800 dark:text-slate-200 mb-1">
          {{ $t('TICKETS.LINK_JIRA_ISSUE') }}
        </span>
        <select
          v-model="ticketForm.jira_issue_id"
          class="block w-full border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-700 dark:text-slate-200"
          :disabled="isLoadingJiraIssues"
        >
          <option
            v-for="issue in availableJiraIssues"
            :key="issue.id"
            :value="issue.id"
          >
            {{ issue.key ? `${issue.key} - ${issue.summary}` : issue.summary }}
          </option>
        </select>
        <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TICKETS.JIRA_LINK_HELP') }}
        </p>
      </label>

      <!-- Selected Messages Preview -->
      <div v-if="selectedMessageIds.length > 0" class="block">
        <span class="block text-sm font-medium text-slate-800 dark:text-slate-200 mb-2">
          {{ $t('TICKETS.SELECTED_MESSAGES_PREVIEW', { count: selectedMessageIds.length }) }}
        </span>
        <div class="max-h-40 overflow-y-auto border border-slate-200 dark:border-slate-600 rounded-md bg-slate-50 dark:bg-slate-800">
          <div
            v-for="message in selectedMessagesPreview"
            :key="message.id"
            class="p-3 border-b border-slate-200 dark:border-slate-600 last:border-b-0"
          >
            <div class="text-xs text-slate-500 dark:text-slate-400 mb-1">
              {{ formatMessageSender(message) }} • {{ formatDate(message.created_at) }}
            </div>
            <div class="text-sm text-slate-700 dark:text-slate-300 line-clamp-2">
              {{ message.content || $t('TICKETS.NO_CONTENT') }}
            </div>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex justify-end gap-2 pt-4">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="onClose"
          :disabled="isLoading"
        >
          {{ $t('TICKETS.CANCEL') }}
        </woot-button>
        
        <woot-button
          variant="smooth"
          color-scheme="primary"
          :is-loading="isLoading"
          :disabled="!ticketForm.title.trim()"
          @click="createTicket"
        >
          {{ $t('TICKETS.CREATE_TICKET') }}
        </woot-button>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  conversationId: {
    type: [String, Number],
    required: true,
  },
  selectedMessageIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'success']);

const store = useStore();
const { t } = useI18n();

// Get current user and conversation data
const currentUser = computed(() => store.getters.getCurrentUser);
const currentChat = computed(() => store.getters.getSelectedChat);

const ticketForm = ref({
  title: '',
  description: '',
  priority: 'medium',
  issue_type: '',
  jira_issue_id: '', // Changed to dropdown selection
  assigned_agent_id: currentUser.value?.id || '',
  conversation_id: props.conversationId,
});

const isLoading = ref(false);
const errors = ref({});

// Get available JIRA issues for this conversation
const availableJiraIssues = ref([]);
const isLoadingJiraIssues = ref(false);

const selectedMessagesPreview = computed(() => {
  const conversationMessages = currentChat.value?.messages || [];
  return conversationMessages.filter(message => 
    props.selectedMessageIds.includes(message.id)
  ).slice(0, 5); // Show max 5 messages in preview
});

const formatMessageSender = (message) => {
  if (message.message_type === 0) {
    return message.sender?.name || t('TICKETS.CUSTOMER');
  }
  return message.sender?.name || t('TICKETS.AGENT');
};

const formatDate = (dateString) => {
  return new Date(dateString).toLocaleString();
};

const fetchJiraIssues = async () => {
  isLoadingJiraIssues.value = true;
  try {
    // This would fetch JIRA issues already linked to this conversation
    // For now, using mock data - you'd replace this with actual API call
    availableJiraIssues.value = [
      { id: '', key: '', summary: t('TICKETS.NO_JIRA_LINK') },
      { id: '1', key: 'PROJ-123', summary: 'Customer login issue' },
      { id: '2', key: 'PROJ-124', summary: 'Payment processing bug' },
      // Add actual API call here to fetch linked JIRA issues
    ];
  } catch (error) {
    console.error('Error fetching JIRA issues:', error);
  } finally {
    isLoadingJiraIssues.value = false;
  }
};

const createTicket = async () => {
  if (!ticketForm.value.title.trim()) {
    return;
  }
  
  isLoading.value = true;
  errors.value = {};
  
  try {
    const ticketData = {
      ...ticketForm.value,
      message_ids: props.selectedMessageIds,
    };
    
    await store.dispatch('tickets/create', ticketData);
    
    useAlert(t('TICKETS.CREATE_SUCCESS'));
    emit('success');
    onClose();
  } catch (error) {
    console.error('Error creating ticket:', error);
    if (error.response?.data?.errors) {
      errors.value = error.response.data.errors;
    }
    useAlert(t('TICKETS.CREATE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const onClose = () => {
  emit('close');
};

onMounted(() => {
  fetchJiraIssues();
});
</script>
