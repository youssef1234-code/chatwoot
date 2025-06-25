<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import EditTicketModal from 'dashboard/components/tickets/EditTicketModal.vue';
import EscalateToJiraModal from 'dashboard/components/tickets/EscalateToJiraModal.vue';
import ViewTicketMessagesModal from 'dashboard/components/tickets/ViewTicketMessagesModal.vue';
import { formatDate } from 'shared/helpers/DateHelper';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  ticket: {
    type: Object,
    required: true,
  },
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['refresh']);

const { t } = useI18n();
const store = useStore();
const isUpdating = ref(false);
const showEditModal = ref(false);
const showEscalateModal = ref(false);
const showViewMessagesModal = ref(false);

const ticketTitle = computed(() => props.ticket.title || 'Untitled Ticket');
const ticketDescription = computed(() => props.ticket.description || '');
const ticketStatus = computed(() => props.ticket.status || 'open');
const ticketPriority = computed(() => props.ticket.priority || 'medium');
const isResolved = computed(() => ticketStatus.value === 'resolved' || ticketStatus.value === 'closed');
const isEscalated = computed(() => ticketStatus.value === 'escalated' || props.ticket.jira_issue_key);

const createdAt = computed(() => {
  if (props.ticket.created_at) {
    return formatDate(new Date(props.ticket.created_at), 'MMM dd, yyyy');
  }
  return '';
});

const getStatusColor = (status) => {
  const colors = {
    open: 'bg-blue-50 text-blue-700 border-blue-200',
    in_progress: 'bg-yellow-50 text-yellow-700 border-yellow-200',
    escalated: 'bg-orange-50 text-orange-700 border-orange-200',
    resolved: 'bg-green-50 text-green-700 border-green-200',
    closed: 'bg-gray-50 text-gray-700 border-gray-200',
  };
  return colors[status] || colors.open;
};

const getPriorityColor = (priority) => {
  const colors = {
    low: 'bg-gray-50 text-gray-700 border-gray-200',
    medium: 'bg-blue-50 text-blue-700 border-blue-200',
    high: 'bg-orange-50 text-orange-700 border-orange-200',
    urgent: 'bg-red-50 text-red-700 border-red-200',
  };
  return colors[priority] || colors.medium;
};

const markAsDone = async () => {
  if (isResolved.value) return;
  
  isUpdating.value = true;
  try {
    await store.dispatch('tickets/updateTicket', {
      id: props.ticket.id,
      status: 'resolved'
    });
    useAlert(t('TICKETS.MARK_AS_DONE_SUCCESS'));
    emit('refresh');
  } catch (error) {
    console.error('Failed to mark ticket as done:', error);
    useAlert(t('TICKETS.MARK_AS_DONE_ERROR'));
  } finally {
    isUpdating.value = false;
  }
};

const openEditModal = () => {
  showEditModal.value = true;
};

const closeEditModal = () => {
  showEditModal.value = false;
};

const onTicketUpdated = () => {
  emit('refresh');
  closeEditModal();
};

const openEscalateModal = () => {
  showEscalateModal.value = true;
};

const closeEscalateModal = () => {
  showEscalateModal.value = false;
};

const onTicketEscalated = () => {
  emit('refresh');
  closeEscalateModal();
};

const openViewMessagesModal = () => {
  showViewMessagesModal.value = true;
};

const closeViewMessagesModal = () => {
  showViewMessagesModal.value = false;
};

const viewJiraIssue = () => {
  if (props.ticket.jira_url) {
    window.open(props.ticket.jira_url, '_blank');
  }
};

// WebSocket event listeners for real-time updates
const handleTicketUpdate = (data) => {
  if (data.ticket_id === props.ticket.id) {
    console.log('TicketItem: Received real-time update for this ticket', data);
    // Emit refresh to parent to reload ticket data
    emit('refresh');
    
    // Show notification if ticket was auto-resolved by JIRA
    if (data.status === 'resolved' && data.jira_issue_key) {
      useAlert(t('TICKETS.JIRA_AUTO_RESOLVED_NOTIFICATION'));
    }
  }
};

const handleJiraIssueUpdate = (data) => {
  if (data.conversation_id === props.conversationId && props.ticket.jira_issue_key) {
    console.log('TicketItem: Received JIRA status update for conversation', data);
    // If this ticket is linked to the updated JIRA issue, refresh
    if (data.issue_key === props.ticket.jira_issue_key && data.completed) {
      emit('refresh');
    }
  }
};

onMounted(() => {
  // Listen for ticket updates
  emitter.on('tickets:ticket-updated', handleTicketUpdate);
  emitter.on('jira:ticket-auto-resolved', handleTicketUpdate);
  emitter.on('jira:issue-status-updated', handleJiraIssueUpdate);
});

onUnmounted(() => {
  // Clean up event listeners
  emitter.off('tickets:ticket-updated', handleTicketUpdate);
  emitter.off('jira:ticket-auto-resolved', handleTicketUpdate);
  emitter.off('jira:issue-status-updated', handleJiraIssueUpdate);
});
</script>

<template>
  <div class="p-4 rounded-xl hover:bg-n-alpha-1 transition-all duration-200 shadow-sm hover:shadow-md border border-n-weak">
    <div class="flex items-start justify-between gap-4">
      <div class="flex-1 min-w-0">
        <!-- Ticket header -->
        <div class="flex items-center gap-3 mb-3">
          <button
            class="inline-flex items-center gap-2 text-purple-700 hover:text-purple-800 font-semibold text-sm bg-purple-50 hover:bg-purple-100 px-3 py-1.5 rounded-lg transition-colors"
            @click="openEditModal"
          >
            <div class="w-4 h-4 bg-purple-600 rounded text-white text-xs flex items-center justify-center font-bold">
              T
            </div>
            #{{ ticket.id }}
          </button>
          
          <span v-if="createdAt" class="text-xs text-n-slate-10 hidden sm:block">
            {{ $t('TICKETS.CREATED') }}: {{ createdAt }}
          </span>
        </div>

        <!-- Ticket title -->
        <h4 class="text-sm font-medium text-n-slate-12 mb-3 line-clamp-2 leading-relaxed">
          {{ ticketTitle }}
        </h4>

        <!-- Ticket description -->
        <p v-if="ticketDescription" class="text-xs text-n-slate-10 mb-3 line-clamp-2">
          {{ ticketDescription }}
        </p>

        <!-- Ticket metadata -->
        <div class="flex flex-wrap items-center gap-2 mb-4">
          <span
            class="px-3 py-1.5 rounded-full text-xs font-medium border shadow-sm"
            :class="getStatusColor(ticketStatus)"
          >
            {{ $t(`TICKETS.STATUS.${ticketStatus.toUpperCase()}`) }}
          </span>
          <span
            class="px-3 py-1.5 rounded-full text-xs font-medium border shadow-sm"
            :class="getPriorityColor(ticketPriority)"
          >
            {{ $t(`TICKETS.PRIORITY.${ticketPriority.toUpperCase()}`) }}
          </span>
          
          <!-- Category Badge -->
          <span
            v-if="ticket.category"
            class="px-3 py-1.5 rounded-full text-xs font-medium border shadow-sm bg-purple-50 text-purple-700 border-purple-200"
          >
            {{ ticket.category }}
          </span>
          
          <!-- JIRA Issue Badge -->
          <button
            v-if="ticket.jira_issue_key"
            class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium bg-blue-50 text-blue-700 border border-blue-200 rounded-full hover:bg-blue-100 transition-colors"
            @click="viewJiraIssue"
            :title="$t('TICKETS.VIEW_IN_JIRA')"
          >
            <i class="ri-external-link-line text-xs"></i>
            {{ ticket.jira_issue_key }}
          </button>
        </div>

        <!-- Action buttons -->
        <div class="flex items-center gap-2 flex-wrap">
          <NextButton
            v-if="!isResolved"
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            :is-loading="isUpdating"
            class="hover:bg-green-50 hover:text-green-700"
            @click="markAsDone"
          >
            <i class="ri-check-line" />
            {{ $t('TICKETS.MARK_AS_DONE') }}
          </NextButton>
          
          <NextButton
            v-if="!isEscalated && !isResolved"
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-orange-50 hover:text-orange-700"
            @click="openEscalateModal"
          >
            <i class="ri-external-link-line" />
            {{ $t('TICKETS.ESCALATE_TO_JIRA') }}
          </NextButton>
          
          <NextButton
            v-if="!isResolved"
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-blue-50 hover:text-blue-700"
            @click="openEditModal"
          >
            <i class="ri-edit-line" />
            {{ $t('TICKETS.EDIT_TICKET') }}
          </NextButton>
          
          <NextButton
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-slate-50 hover:text-slate-700"
            @click="openViewMessagesModal"
          >
            <i class="ri-message-3-line" />
            {{ $t('TICKETS.VIEW_MESSAGES') }}
          </NextButton>
        </div>
      </div>
    </div>
    
    <!-- Modals -->
    <EditTicketModal
      v-if="showEditModal"
      :ticket="ticket"
      @close="closeEditModal"
      @updated="onTicketUpdated"
    />
    
    <EscalateToJiraModal
      v-if="showEscalateModal"
      :ticket="ticket"
      @close="closeEscalateModal"
      @escalated="onTicketEscalated"
    />
    
    <ViewTicketMessagesModal
      v-if="showViewMessagesModal"
      :ticket="ticket"
      @close="closeViewMessagesModal"
    />
  </div>
</template>

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
