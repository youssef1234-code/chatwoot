<template>
  <Modal
    v-model:show="showModal"
    :on-close="() => $emit('close')"
    size="medium"
    :full-width="true"
  >
    <div class="p-6">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-xl font-semibold text-n-slate-12">
            {{ $t('TICKETS.DETAIL.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-10 mt-1">
            {{ $t('TICKETS.DETAIL.SUBTITLE', { id: ticket.id }) }}
          </p>
        </div>
        <div class="flex items-center gap-2">
          <NextButton
            variant="outline"
            size="sm"
            @click="refreshTicket"
            :is-loading="isRefreshing"
          >
            <Icon icon="i-lucide-refresh-cw" class="w-4 h-4 mr-2" />
            {{ $t('TICKETS.DETAIL.REFRESH') }}
          </NextButton>
        </div>
      </div>
      <div class="flex h-full max-h-[70vh]">
        <!-- Left Panel - Ticket Details -->
        <div class="flex-1 pr-6 border-r border-n-weak overflow-y-auto">
          <!-- Ticket Info -->
          <div class="space-y-6">
            <!-- Status and Priority -->
            <div class="flex items-center gap-4">
              <div>
                <NextSelect
                  v-model="ticketForm.status"
                  :label="$t('TICKETS.DETAIL.STATUS')"
                  name="status"
                  :options="statusOptions"
                  @update:model-value="updateTicket"
                />
              </div>
              <div>
                <NextSelect
                  v-model="ticketForm.priority"
                  :label="$t('TICKETS.DETAIL.PRIORITY')"
                  name="priority"
                  :options="priorityOptions"
                  @update:model-value="updateTicket"
                />
              </div>
            </div>

            <!-- Title and Description -->
            <div>
              <label class="block text-sm font-medium text-n-slate-10 mb-1">
                {{ $t('TICKETS.DETAIL.TITLE') }}
              </label>
              <NextInput
                v-model="ticketForm.title"
                :placeholder="$t('TICKETS.DETAIL.TITLE_PLACEHOLDER')"
                @blur="updateTicket"
              />
            </div>

            <div>
              <NextTextarea
                v-model="ticketForm.description"
                :label="$t('TICKETS.DETAIL.DESCRIPTION')"
                name="description"
                :placeholder="$t('TICKETS.DETAIL.DESCRIPTION_PLACEHOLDER')"
                :rows="4"
                @blur="updateTicket"
              />
            </div>

            <!-- Assignment -->
            <div>
              <NextSelect
                v-model="ticketForm.assigned_agent_id"
                :label="$t('TICKETS.DETAIL.ASSIGNED_AGENT')"
                name="assigned_agent"
                :options="agentOptions"
                :placeholder="$t('TICKETS.DETAIL.SELECT_AGENT')"
                @update:model-value="updateTicket"
              />
            </div>

            <!-- JIRA Integration -->
            <div v-if="ticket.jira_issue_key || canEscalateToJira" class="space-y-4">
              <h3 class="text-lg font-medium text-n-slate-12">
                {{ $t('TICKETS.DETAIL.JIRA_INTEGRATION') }}
              </h3>
              
              <!-- Existing JIRA Issue -->
              <div v-if="ticket.jira_issue_key" class="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <Icon icon="i-lucide-external-link" class="w-5 h-5 text-blue-600" />
                    <span class="font-medium text-blue-800 dark:text-blue-200">
                      {{ ticket.jira_issue_key }}
                    </span>
                  </div>
                  <NextButton
                    variant="solid"
                    color="blue"
                    size="sm"
                    @click="openJiraIssue"
                  >
                    {{ $t('TICKETS.VIEW_IN_JIRA') }}
                  </NextButton>
                </div>
                
                <!-- JIRA Issue Details -->
                <div v-if="jiraIssueDetails" class="space-y-3">
                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <span class="text-sm font-medium text-blue-700 block">
                        {{ $t('TICKETS.DETAIL.JIRA_STATUS') }}
                      </span>
                      <span class="text-sm text-blue-800 font-medium">
                        {{ jiraIssueDetails.status }}
                      </span>
                    </div>
                    <div>
                      <span class="text-sm font-medium text-blue-700 block">
                        Priority
                      </span>
                      <span class="text-sm text-blue-800 font-medium">
                        {{ jiraIssueDetails.priority || 'Not set' }}
                      </span>
                    </div>
                  </div>
                  
                  <div>
                    <span class="text-sm font-medium text-blue-700 block mb-1">
                      {{ $t('TICKETS.DETAIL.JIRA_SUMMARY') }}
                    </span>
                    <p class="text-sm text-blue-800">
                      {{ jiraIssueDetails.summary }}
                    </p>
                  </div>
                  
                  <div v-if="jiraIssueDetails.description">
                    <span class="text-sm font-medium text-blue-700 block mb-1">
                      Description
                    </span>
                    <p class="text-sm text-blue-800 line-clamp-3">
                      {{ jiraIssueDetails.description }}
                    </p>
                  </div>
                  
                  <div v-if="jiraIssueDetails.assignee">
                    <span class="text-sm font-medium text-blue-700 block">
                      Assignee
                    </span>
                    <span class="text-sm text-blue-800">
                      {{ jiraIssueDetails.assignee.displayName }}
                    </span>
                  </div>
                </div>
                
                <!-- Loading state for JIRA details -->
                <div v-else-if="isLoadingJira" class="flex items-center gap-2 text-blue-600">
                  <Icon icon="i-lucide-loader-2" class="w-4 h-4 animate-spin" />
                  <span class="text-sm">Loading JIRA details...</span>
                </div>
              </div>
              
              <!-- Escalate to JIRA -->
              <div v-else-if="canEscalateToJira" class="p-4 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg border border-yellow-200">
                <div class="flex items-center justify-between">
                  <div>
                    <h4 class="font-medium text-yellow-800 dark:text-yellow-200 mb-1">
                      {{ $t('TICKETS.DETAIL.ESCALATE_TO_JIRA') }}
                    </h4>
                    <p class="text-sm text-yellow-700 dark:text-yellow-300">
                      {{ $t('TICKETS.DETAIL.ESCALATE_DESCRIPTION') }}
                    </p>
                  </div>
                  <NextButton
                    variant="solid"
                    color="yellow"
                    size="sm"
                    :is-loading="isEscalating"
                    @click="escalateToJira"
                  >
                    {{ $t('TICKETS.DETAIL.ESCALATE') }}
                  </NextButton>
                </div>
              </div>
            </div>

            <!-- Conversation Link -->
            <div>
              <h3 class="text-lg font-medium text-n-slate-12 mb-3">
                {{ $t('TICKETS.DETAIL.LINKED_CONVERSATION') }}
              </h3>
              <div class="p-4 bg-n-alpha-2 rounded-lg border border-n-weak">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <Icon icon="i-lucide-message-circle" class="w-5 h-5 text-n-slate-9" />
                    <div>
                      <p class="font-medium text-n-slate-12">
                        {{ $t('TICKETS.DETAIL.CONVERSATION_ID', { id: ticket.conversation?.display_id }) }}
                      </p>
                      <p class="text-sm text-n-slate-9">
                        {{ ticket.conversation?.status }}
                      </p>
                    </div>
                  </div>
                  <NextButton
                    variant="outline"
                    size="sm"
                    @click="openConversation"
                  >
                    {{ $t('TICKETS.DETAIL.OPEN_CONVERSATION') }}
                  </NextButton>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Right Panel - Messages -->
        <div class="w-96 pl-6 flex flex-col">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-medium text-n-slate-12">
              {{ $t('TICKETS.DETAIL.LINKED_MESSAGES') }}
            </h3>
            <span class="text-sm text-n-slate-9">
              {{ messages.length }} {{ $t('TICKETS.DETAIL.MESSAGES') }}
            </span>
          </div>

          <!-- Messages List -->
          <div class="flex-1 overflow-y-auto space-y-3">
            <div
              v-if="isLoadingMessages"
              class="space-y-3"
            >
              <div
                v-for="n in 3"
                :key="n"
                class="animate-pulse bg-n-alpha-2 rounded-lg p-3 h-20"
              />
            </div>

            <div v-else-if="messages.length === 0" class="text-center py-8">
              <Icon icon="i-lucide-message-circle" class="w-12 h-12 text-n-slate-7 mx-auto mb-2" />
              <p class="text-sm text-n-slate-9">
                {{ $t('TICKETS.NO_MESSAGES_IN_TICKET') }}
              </p>
            </div>

            <MessageItem
              v-for="message in messages"
              :key="message.id"
              :message="message"
              compact
            />
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-between mt-6 pt-4 border-t border-n-weak">
        <div class="text-sm text-n-slate-9">
          {{ $t('TICKETS.DETAIL.CREATED_AT') }}: {{ formatDate(ticket.created_at) }}
          <span v-if="ticket.resolved_at" class="ml-4">
            {{ $t('TICKETS.DETAIL.RESOLVED_AT') }}: {{ formatDate(ticket.resolved_at) }}
          </span>
        </div>
        <div class="flex items-center gap-2">
          <NextButton
            variant="outline"
            @click="$emit('close')"
          >
            {{ $t('TICKETS.DETAIL.CLOSE') }}
          </NextButton>
          <NextButton
            v-if="ticket.status !== 'resolved' && ticket.status !== 'closed'"
            color="green"
            @click="resolveTicket"
            :is-loading="isUpdating"
          >
            {{ $t('TICKETS.DETAIL.RESOLVE') }}
          </NextButton>
        </div>
      </div>
    </div>
  </Modal>
</template>

<script>
import { ref, computed, onMounted, reactive, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { format } from 'date-fns';

import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextTextarea from 'v3/components/Form/Textarea.vue';
import NextSelect from 'v3/components/Form/Select.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MessageItem from './MessageItem.vue';

import { useAlert } from 'dashboard/composables';
import TicketsAPI from 'dashboard/api/tickets';

export default {
  name: 'TicketDetailModal',
  components: {
    Modal,
    NextButton,
    NextInput,
    NextTextarea,
    NextSelect,
    Icon,
    MessageItem,
  },
  props: {
    ticket: {
      type: Object,
      required: true,
    },
    currentUser: {
      type: Object,
      required: true,
    },
  },
  emits: ['close', 'updated', 'refresh'],
  setup(props, { emit }) {
    const store = useStore();
    const { t } = useI18n();
    const router = useRouter();

    // State
    const isUpdating = ref(false);
    const isRefreshing = ref(false);
    const isLoadingMessages = ref(false);
    const isLoadingJira = ref(false);
    const isEscalating = ref(false);
    const messages = ref([]);
    const jiraIssueDetails = ref(null);
    const showModal = ref(true);

    // Form
    const ticketForm = reactive({
      title: props.ticket.title || '',
      description: props.ticket.description || '',
      status: props.ticket.status || 'open',
      priority: props.ticket.priority || 'medium',
      assigned_agent_id: props.ticket.assigned_agent?.id || '',
    });

    // Computed
    const statusOptions = computed(() => [
      { label: t('TICKETS.STATUS.OPEN'), value: 'open' },
      { label: t('TICKETS.STATUS.IN_PROGRESS'), value: 'in_progress' },
      { label: t('TICKETS.STATUS.ESCALATED'), value: 'escalated' },
      { label: t('TICKETS.STATUS.RESOLVED'), value: 'resolved' },
      { label: t('TICKETS.STATUS.CLOSED'), value: 'closed' },
    ]);

    const priorityOptions = computed(() => [
      { label: t('TICKETS.PRIORITY.LOW'), value: 'low' },
      { label: t('TICKETS.PRIORITY.MEDIUM'), value: 'medium' },
      { label: t('TICKETS.PRIORITY.HIGH'), value: 'high' },
      { label: t('TICKETS.PRIORITY.URGENT'), value: 'urgent' },
    ]);

    const agentOptions = computed(() => {
      const agents = store.getters['agents/getAgents'];
      return [
        { label: t('TICKETS.UNASSIGNED'), value: '' },
        ...agents.map(agent => ({
          label: agent.name,
          value: agent.id,
        })),
      ];
    });

    const canEscalateToJira = computed(() => {
      return !props.ticket.jira_issue_key && 
             (props.ticket.status === 'open' || props.ticket.status === 'in_progress');
    });

    // Methods
    const loadMessages = async () => {
      isLoadingMessages.value = true;
      try {
        const response = await TicketsAPI.getMessages(props.ticket.id);
        messages.value = response.data.messages || [];
      } catch (error) {
        console.error('Failed to load ticket messages:', error);
        useAlert(t('TICKETS.DETAIL.MESSAGES_LOAD_ERROR'));
      } finally {
        isLoadingMessages.value = false;
      }
    };

    const updateTicket = async () => {
      isUpdating.value = true;
      try {
        await store.dispatch('tickets/updateTicket', {
          id: props.ticket.id,
          ...ticketForm,
        });
        emit('updated');
        useAlert(t('TICKETS.UPDATE_SUCCESS'));
      } catch (error) {
        console.error('Failed to update ticket:', error);
        useAlert(t('TICKETS.UPDATE_ERROR'));
      } finally {
        isUpdating.value = false;
      }
    };

    const resolveTicket = async () => {
      isUpdating.value = true;
      try {
        await store.dispatch('tickets/resolve', props.ticket.id);
        emit('updated');
        useAlert(t('TICKETS.RESOLVE_SUCCESS'));
      } catch (error) {
        console.error('Failed to resolve ticket:', error);
        useAlert(t('TICKETS.RESOLVE_ERROR'));
      } finally {
        isUpdating.value = false;
      }
    };

    const loadJiraDetails = async () => {
      if (!props.ticket.jira_issue_key) return;
      
      isLoadingJira.value = true;
      try {
        // Import JIRA API
        const JiraAPI = await import('dashboard/api/integrations/jira');
        const response = await JiraAPI.default.getIssue(props.ticket.jira_issue_key);
        jiraIssueDetails.value = response.data;
      } catch (error) {
        console.error('Failed to load JIRA details:', error);
        // Don't show error alert as this is optional enhancement
      } finally {
        isLoadingJira.value = false;
      }
    };

    const escalateToJira = async () => {
      isEscalating.value = true;
      try {
        // Automatically create JIRA issue with ticket details
        const JiraAPI = await import('dashboard/api/integrations/jira');
        const response = await JiraAPI.default.createIssue({
          summary: props.ticket.title || `Ticket #${props.ticket.id}`,
          description: props.ticket.description || 'No description provided',
          issueType: 'Task',
          priority: props.ticket.priority || 'Medium',
        });
        
        // Link the created JIRA issue to the ticket
        await store.dispatch('tickets/linkJiraIssue', {
          ticketId: props.ticket.id,
          jiraIssueKey: response.data.key,
          jiraUrl: response.data.self,
        });
        
        emit('updated');
        useAlert(t('TICKETS.ESCALATE_SUCCESS'));
        
        // Load the newly created JIRA details
        await loadJiraDetails();
      } catch (error) {
        console.error('Failed to escalate to JIRA:', error);
        useAlert(t('TICKETS.ESCALATE_ERROR'));
      } finally {
        isEscalating.value = false;
      }
    };

    const refreshTicket = async () => {
      isRefreshing.value = true;
      try {
        await store.dispatch('tickets/fetchTicket', props.ticket.id);
        await loadMessages();
        emit('refresh');
        useAlert(t('TICKETS.DETAIL.REFRESHED'));
      } catch (error) {
        console.error('Failed to refresh ticket:', error);
        useAlert(t('TICKETS.DETAIL.REFRESH_ERROR'));
      } finally {
        isRefreshing.value = false;
      }
    };

    const openConversation = () => {
      if (props.ticket.conversation?.id) {
        const accountId = router.currentRoute.value.params.accountId;
        const conversationUrl = `/app/accounts/${accountId}/conversations/${props.ticket.conversation.id}`;
        window.open(conversationUrl, '_blank');
      }
    };

    const openJiraIssue = () => {
      if (props.ticket.jira_url) {
        window.open(props.ticket.jira_url, '_blank');
      } else if (props.ticket.jira_issue_key) {
        // Construct JIRA URL from issue key
        const jiraBaseUrl = window.chatwootConfig?.jiraBaseUrl || 'https://your-domain.atlassian.net';
        const jiraUrl = `${jiraBaseUrl}/browse/${props.ticket.jira_issue_key}`;
        window.open(jiraUrl, '_blank');
      }
    };

    const formatDate = (dateString) => {
      if (!dateString) return '';
      try {
        return format(new Date(dateString), 'MMM dd, yyyy HH:mm');
      } catch (error) {
        return dateString;
      }
    };

    // Lifecycle
    onMounted(() => {
      loadMessages();
      
      // Load JIRA details if ticket has JIRA issue
      if (props.ticket.jira_issue_key) {
        // This would load JIRA issue details
        // Implementation depends on JIRA integration setup
      }
    });

    // Watch for ticket changes
    watch(() => props.ticket, (newTicket) => {
      ticketForm.title = newTicket.title || '';
      ticketForm.description = newTicket.description || '';
      ticketForm.status = newTicket.status || 'open';
      ticketForm.priority = newTicket.priority || 'medium';
      ticketForm.assigned_agent_id = newTicket.assigned_agent?.id || '';
    }, { immediate: true });

    // Lifecycle
    onMounted(() => {
      loadMessages();
      if (props.ticket.jira_issue_key) {
        loadJiraDetails();
      }
    });

    return {
      // State
      isUpdating,
      isRefreshing,
      isLoadingMessages,
      isLoadingJira,
      isEscalating,
      messages,
      jiraIssueDetails,
      ticketForm,
      showModal,
      
      // Computed
      statusOptions,
      priorityOptions,
      agentOptions,
      canEscalateToJira,
      
      // Methods
      loadMessages,
      loadJiraDetails,
      updateTicket,
      resolveTicket,
      escalateToJira,
      refreshTicket,
      openConversation,
      openJiraIssue,
      formatDate,
    };
  },
};
</script>

<style scoped>
/* Custom scrollbar for messages */
.overflow-y-auto::-webkit-scrollbar {
  width: 4px;
}

.overflow-y-auto::-webkit-scrollbar-track {
  background: transparent;
}

.overflow-y-auto::-webkit-scrollbar-thumb {
  background: rgba(156, 163, 175, 0.5);
  border-radius: 2px;
}

.overflow-y-auto::-webkit-scrollbar-thumb:hover {
  background: rgba(156, 163, 175, 0.7);
}
</style>
