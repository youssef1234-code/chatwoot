<template>
  <Modal
    :show="true"
    :on-close="onClose"
    :close-on-backdrop-click="false"
  >
    <div class="w-full max-w-2xl mx-auto">
      <div class="flex flex-col h-[600px]">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600">
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {{ $t('TICKETS.CREATE_TICKET') }}
          </h2>
        </div>
        
        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-6">
          <form @submit.prevent="createTicket" class="space-y-4">
            <!-- Title -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('TICKETS.TITLE') }} *
              </label>
              <input
                v-model="ticketForm.title"
                type="text"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                :placeholder="$t('TICKETS.TITLE_PLACEHOLDER')"
                required
              />
              <p v-if="errors.title" class="mt-1 text-sm text-red-600">{{ errors.title[0] }}</p>
            </div>

            <!-- Description -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('TICKETS.DESCRIPTION') }}
              </label>
              <textarea
                v-model="ticketForm.description"
                rows="4"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                :placeholder="$t('TICKETS.DESCRIPTION_PLACEHOLDER')"
              ></textarea>
              <p v-if="errors.description" class="mt-1 text-sm text-red-600">{{ errors.description[0] }}</p>
            </div>

            <!-- Priority -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('TICKETS.PRIORITY.LABEL') }}
              </label>
              <select
                v-model="ticketForm.priority"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
              >
                <option value="low">{{ $t('TICKETS.PRIORITY.LOW') }}</option>
                <option value="medium">{{ $t('TICKETS.PRIORITY.MEDIUM') }}</option>
                <option value="high">{{ $t('TICKETS.PRIORITY.HIGH') }}</option>
                <option value="urgent">{{ $t('TICKETS.PRIORITY.URGENT') }}</option>
              </select>
            </div>

            <!-- Issue Type -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('TICKETS.ISSUE_TYPE') }}
              </label>
              <input
                v-model="ticketForm.issue_type"
                type="text"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                :placeholder="$t('TICKETS.ISSUE_TYPE_PLACEHOLDER')"
              />
            </div>

            <!-- Link to JIRA Issue -->
            <div v-if="isLoadingJiraIssues">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('TICKETS.LINK_JIRA_ISSUE') }}
              </label>
              <div class="w-full px-3 py-2 border border-n-slate-6 rounded-md bg-n-slate-1 text-n-slate-10 text-sm">
                {{ $t('TICKETS.LOADING_JIRA_ISSUES') }}
              </div>
            </div>
            <div v-else-if="availableJiraIssues.length > 0">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('TICKETS.LINK_JIRA_ISSUE') }}
              </label>
              <select
                v-model="ticketForm.jira_issue_key"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
              >
                <option value="">{{ $t('TICKETS.SELECT_JIRA_ISSUE') }}</option>
                <option
                  v-for="issue in availableJiraIssues"
                  :key="issue.key"
                  :value="issue.key"
                >
                  {{ `${issue.key} - ${issue.summary}` }} ({{ issue.status }})
                </option>
              </select>
              <p class="mt-1 text-xs text-n-slate-10">
                {{ $t('TICKETS.JIRA_LINK_HELP') }}
              </p>
            </div>


            <!-- Selected Messages Preview -->
            <div v-if="selectedMessageIds.length > 0">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('TICKETS.SELECTED_MESSAGES_PREVIEW', { count: selectedMessageIds.length }) }}
              </label>
              <div class="max-h-40 overflow-y-auto border border-n-slate-6 rounded-md bg-n-slate-1">
                <div
                  v-for="message in selectedMessagesPreview"
                  :key="message.id"
                  class="p-3 border-b border-n-slate-4 last:border-b-0"
                >
                  <div class="text-xs text-n-slate-10 mb-1">
                    {{ formatMessageSender(message) }} • {{ formatDate(message.created_at) }}
                  </div>
                  <div class="text-sm text-n-slate-12 line-clamp-2">
                    {{ message.content || $t('TICKETS.NO_CONTENT') }}
                  </div>
                </div>
              </div>
            </div>
          </form>
        </div>

        <!-- Footer -->
        <div class="flex justify-end gap-3 p-6 border-t border-slate-200 dark:border-slate-600">
          <Button
            ghost
            slate
            :label="$t('TICKETS.CANCEL')"
            @click="onClose"
            :disabled="isLoading"
          />
          
          <Button
            blue
            :label="$t('TICKETS.CREATE_TICKET')"
            :loading="isLoading"
            :disabled="!ticketForm.title.trim()"
            @click="createTicket"
          />
        </div>
      </div>
    </div>
  </Modal>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import JiraAPI from 'dashboard/api/integrations/jira';

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

const emit = defineEmits(['close', 'created']);

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
  jira_issue_key: '',
  assigned_agent_id: currentUser.value?.id || '',
  conversation_id: props.conversationId,
});

const isLoading = ref(false);
const errors = ref({});

// JIRA issues loaded from API
const availableJiraIssues = ref([]);
const isLoadingJiraIssues = ref(false);

// Load JIRA issues for the conversation
const loadJiraIssues = async () => {
  if (!props.conversationId) return;
  
  isLoadingJiraIssues.value = true;
  try {
    const response = await JiraAPI.getLinkedIssues(props.conversationId);
    availableJiraIssues.value = (response.data || []).map(issue => ({
      key: issue.key,
      summary: issue.summary || issue.title,
      status: issue.status,
      url: issue.url
    }));
  } catch (error) {
    console.error('Failed to load JIRA issues:', error);
    availableJiraIssues.value = [];
  } finally {
    isLoadingJiraIssues.value = false;
  }
};

const selectedMessagesPreview = computed(() => {
  const conversation = currentChat.value;
  if (!conversation || !conversation.messages) {
    return [];
  }
  
  return conversation.messages
    .filter(message => props.selectedMessageIds.includes(message.id))
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

const createTicket = async () => {
  if (!ticketForm.value.title.trim()) {
    return;
  }
  
  isLoading.value = true;
  errors.value = {};
  
  try {
    console.log('Hi !');
    console.log('Creating ticket with data:', ticketForm.value);
    console.log('Selected message IDs:', props.selectedMessageIds);
    const ticketData = {
      ...ticketForm.value,
      message_ids: props.selectedMessageIds,
    };
    
    await store.dispatch('tickets/create', ticketData);
    
    useAlert(t('TICKETS.CREATE_SUCCESS'));
    emit('created');
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

// Load JIRA issues when component mounts
onMounted(() => {
  loadJiraIssues();
});

const onClose = () => {
  emit('close');
};
</script>
