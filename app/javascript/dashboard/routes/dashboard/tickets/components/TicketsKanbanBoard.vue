<template>
  <div class="flex h-full overflow-x-auto gap-6 min-h-96 p-6 relative">
    <!-- Loading overlay for actions -->
    <div
      v-if="isResolving || isEscalating"
      class="absolute inset-0 bg-black bg-opacity-20 backdrop-blur-sm flex items-center justify-center z-50"
    >
      <div class="bg-white rounded-lg shadow-xl p-6 flex items-center gap-4">
        <Icon icon="i-lucide-loader-2" class="w-6 h-6 animate-spin text-blue-600" />
        <span class="font-medium">
          {{ isResolving ? $t('TICKETS.KANBAN.RESOLVING') : $t('TICKETS.KANBAN.ESCALATING') }}
        </span>
      </div>
    </div>

    <KanbanColumn
      v-for="column in visibleColumns"
      :key="column.key"
      :title="column.title"
      :tickets="column.tickets"
      :is-loading="isLoading"
      :status="column.status"
      :color="column.color"
      :can-accept-drop="isValidTransition"
      class="flex-1 min-w-80"
      @ticket-move="handleTicketMove"
      @ticket-click="handleTicketClick"
      @enhance-with-ai="$emit('enhance-with-ai', $event)"
    />

    <!-- Escalation Modal -->
    <EscalationModal
      :show="showEscalationModal"
      :ticket="ticketToEscalate"
      :is-loading="isEscalating"
      @close="handleEscalationModalClose"
      @escalate="handleEscalationConfirm"
    />
  </div>
</template>

<script>
import { computed, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

import KanbanColumn from './KanbanColumn.vue';
import EscalationModal from './EscalationModal.vue';

import { useAlert } from 'dashboard/composables';

export default {
  name: 'TicketsKanbanBoard',
  components: {
    KanbanColumn,
    EscalationModal,
  },
  props: {
    tickets: {
      type: Array,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
    currentUser: {
      type: Object,
      required: true,
    },
    isAiEnhancementEnabled: {
      type: Boolean,
      default: false,
    },
    selectedStatuses: {
      type: Array,
      default: () => [],
    },
  },
  emits: ['ticket-updated', 'refresh', 'enhance-with-ai', 'ticket-click', 'ticket-escalate'],
  setup(props, { emit }) {
    const store = useStore();
    const { t } = useI18n();

    // State
    const showEscalationModal = ref(false);
    const ticketToEscalate = ref(null);
    const isEscalating = ref(false);
    const isResolving = ref(false);

    // Computed - Organize tickets by status
    const notDoneTickets = computed(() => {
      return props.tickets.filter(ticket => ticket.status === 'open');
    });

    const inProgressTickets = computed(() => {
      return props.tickets.filter(ticket => {
        // Explicitly in progress status takes priority - even if escalated
        if (ticket.status === 'in_progress') {
          return true;
        }
        
        // JIRA linked tickets that are actively being worked on
        // Higher priority: if jira_in_progress is true, show here regardless of escalation
        if (ticket.jira_in_progress && ticket.status !== 'resolved' && ticket.status !== 'closed') {
          return true;
        }
        
        return false;
      });
    });

    console.log('PROPS TICKETS:', props.tickets);

    const escalatedTickets = computed(() => {
      return props.tickets.filter(ticket => {
        // Only show escalated status tickets that are NOT in progress or actively worked on in JIRA
        return ticket.status === 'escalated' && ticket.status !== 'in_progress' && !ticket.jira_in_progress;
      });
    });

    const doneTickets = computed(() => {
      return props.tickets.filter(ticket => 
        ticket.status === 'resolved' || ticket.status === 'closed' || ticket.status === 'done'
      );
    });

    // Define all possible columns
    const allColumns = computed(() => [
      {
        key: 'not_done',
        title: t('TICKETS.KANBAN.NOT_DONE'),
        status: 'not_done',
        color: 'blue',
        tickets: notDoneTickets.value,
        statusFilters: ['open']
      },
      {
        key: 'escalated',
        title: t('TICKETS.KANBAN.ESCALATED'),
        status: 'escalated',
        color: 'orange',
        tickets: escalatedTickets.value,
        statusFilters: ['escalated']
      },
      {
        key: 'in_progress',
        title: t('TICKETS.KANBAN.IN_PROGRESS'),
        status: 'in_progress',
        color: 'yellow',
        tickets: inProgressTickets.value,
        statusFilters: ['in_progress']
      },
      {
        key: 'done',
        title: t('TICKETS.KANBAN.DONE'),
        status: 'done',
        color: 'green',
        tickets: doneTickets.value,
        statusFilters: ['resolved', 'closed']
      }
    ]);

    // Show only columns that match selected statuses, or all if none selected
    const visibleColumns = computed(() => {
      if (props.selectedStatuses.length === 0) {
        return allColumns.value;
      }
      
      return allColumns.value.filter(column => 
        column.statusFilters.some(status => props.selectedStatuses.includes(status))
      );
    });

    // Methods
    const isValidTransition = (ticket, newStatus) => {
      const currentStatus = getTicketDisplayStatus(ticket);
      
      // Only allow transitions from 'not_done' to 'done' or 'escalated'
      if (currentStatus === 'not_done') {
        return newStatus === 'done' || newStatus === 'escalated';
      }
      
      // No other transitions are allowed
      return false;
    };

    const getTicketDisplayStatus = (ticket) => {
      // Priority: jira_in_progress > escalated > resolved/closed > open
      if (ticket.jira_in_progress) {
        return 'in_progress';
      }
      if (ticket.jira_issue_key || ticket.status === 'escalated') {
        return 'escalated';
      }
      if (ticket.status === 'resolved' || ticket.status === 'closed') {
        return 'done';
      }
      return 'not_done'; // open, in_progress
    };

    const handleTicketMove = async (ticket, newStatus) => {
      // Check if the transition is valid
      if (!isValidTransition(ticket, newStatus)) {
        const currentStatus = getTicketDisplayStatus(ticket);
        useAlert(t('TICKETS.KANBAN.INVALID_TRANSITION', { 
          from: t(`TICKETS.KANBAN.${currentStatus.toUpperCase()}`),
          to: t(`TICKETS.KANBAN.${newStatus.toUpperCase()}`)
        }));
        return false;
      }

      try {
        if (newStatus === 'done') {
          // Show loading state and resolve ticket
          isResolving.value = true;
          await store.dispatch('tickets/resolve', ticket.id);
          emit('ticket-updated');
          useAlert(t('TICKETS.KANBAN.TICKET_RESOLVED'));
          isResolving.value = false;
        } else if (newStatus === 'escalated') {
          // Show escalation modal
          ticketToEscalate.value = ticket;
          showEscalationModal.value = true;
          // Don't return true yet - wait for modal confirmation
          return null; // Indicates pending action
        }
        
        return true;
      } catch (error) {
        console.error('Failed to update ticket status:', error);
        useAlert(t('TICKETS.KANBAN.STATUS_UPDATE_ERROR'));
        return false;
      } finally {
        isResolving.value = false;
      }
    };

    const handleEscalationModalClose = () => {
      showEscalationModal.value = false;
      ticketToEscalate.value = null;
    };

    const handleEscalationConfirm = async ({ ticket, note }) => {
      try {
        isEscalating.value = true;
        
        // Call the escalate action with the note
        await store.dispatch('tickets/escalate', { 
          id: ticket.id, 
          note: note || undefined 
        });
        
        emit('ticket-updated');
        useAlert(t('TICKETS.KANBAN.ESCALATION_INITIATED'));
        handleEscalationModalClose();
        
      } catch (error) {
        console.error('Failed to escalate ticket:', error);
        useAlert(t('TICKETS.KANBAN.STATUS_UPDATE_ERROR'));
      } finally {
        isEscalating.value = false;
      }
    };

    const handleTicketClick = (ticket) => {
      emit('ticket-click', ticket);
    };

    return {
      // State
      showEscalationModal,
      ticketToEscalate,
      isEscalating,
      isResolving,
      
      // Computed
      notDoneTickets,
      inProgressTickets,
      escalatedTickets,
      doneTickets,
      allColumns,
      visibleColumns,
      
      // Methods
      isValidTransition,
      getTicketDisplayStatus,
      handleTicketMove,
      handleEscalationModalClose,
      handleEscalationConfirm,
      handleTicketClick,
    };
  },
};
</script>

<style scoped>
/* Kanban board styles */
.kanban-board {
  min-width: fit-content;
}
</style>
