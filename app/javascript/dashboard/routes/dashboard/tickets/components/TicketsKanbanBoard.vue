<template>
  <div class="flex h-full overflow-x-auto gap-6 min-h-96">
    <!-- Not Done Column -->
    <KanbanColumn
      :title="$t('TICKETS.KANBAN.NOT_DONE')"
      :tickets="notDoneTickets"
      :is-loading="isLoading"
      status="not_done"
      color="blue"
      @ticket-move="handleTicketMove"
      @ticket-click="handleTicketClick"
      @enhance-with-ai="$emit('enhance-with-ai', $event)"
    />

    <!-- In Progress Column -->
    <KanbanColumn
      :title="$t('TICKETS.KANBAN.IN_PROGRESS')"
      :tickets="inProgressTickets"
      :is-loading="isLoading"
      status="in_progress"
      color="yellow"
      @ticket-move="handleTicketMove"
      @ticket-click="handleTicketClick"
      @enhance-with-ai="$emit('enhance-with-ai', $event)"
    />

    <!-- Escalated Column -->
    <KanbanColumn
      :title="$t('TICKETS.KANBAN.ESCALATED')"
      :tickets="escalatedTickets"
      :is-loading="isLoading"
      status="escalated"
      color="orange"
      @ticket-move="handleTicketMove"
      @ticket-click="handleTicketClick"
      @enhance-with-ai="$emit('enhance-with-ai', $event)"
    />

    <!-- Done Column -->
    <KanbanColumn
      :title="$t('TICKETS.KANBAN.DONE')"
      :tickets="doneTickets"
      :is-loading="isLoading"
      status="done"
      color="green"
      @ticket-move="handleTicketMove"
      @ticket-click="handleTicketClick"
      @enhance-with-ai="$emit('enhance-with-ai', $event)"
    />

  </div>
</template>

<script>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

import KanbanColumn from './KanbanColumn.vue';

import { useAlert } from 'dashboard/composables';

export default {
  name: 'TicketsKanbanBoard',
  components: {
    KanbanColumn,
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
  },
  emits: ['ticket-updated', 'refresh', 'enhance-with-ai', 'ticket-click'],
  setup(props, { emit }) {
    const store = useStore();
    const { t } = useI18n();

    // Computed - Organize tickets by status
    const notDoneTickets = computed(() => {
      return props.tickets.filter(ticket => ticket.status === 'open');
    });

    const inProgressTickets = computed(() => {
      return props.tickets.filter(ticket => ticket.status === 'in_progress');
    });

    const escalatedTickets = computed(() => {
      return props.tickets.filter(ticket => ticket.status === 'escalated');
    });

    const doneTickets = computed(() => {
      return props.tickets.filter(ticket => 
        ticket.status === 'resolved' || ticket.status === 'closed'
      );
    });

    // Methods
    const handleTicketMove = async (ticket, newStatus) => {
      try {
        // Map kanban status to ticket status
        const statusMap = {
          'not_done': 'open',
          'in_progress': 'in_progress',
          'escalated': 'escalated',
          'done': 'resolved',
        };

        const targetStatus = statusMap[newStatus];

        // Use specific API methods for certain status changes
        if (targetStatus === 'resolved') {
          await store.dispatch('tickets/resolve', ticket.id);
        } else if (targetStatus === 'escalated') {
          // For escalation, prompt for JIRA issue key
          const jiraIssueKey = prompt(t('TICKETS.KANBAN.ENTER_JIRA_KEY'));
          if (jiraIssueKey) {
            await store.dispatch('tickets/escalateToJira', {
              ticketId: ticket.id,
              jiraIssueKey,
            });
          } else {
            return; // User cancelled
          }
        } else {
          await store.dispatch('tickets/updateTicket', {
            id: ticket.id,
            status: targetStatus,
          });
        }

        emit('ticket-updated');
        useAlert(t('TICKETS.KANBAN.STATUS_UPDATED'));
      } catch (error) {
        console.error('Failed to update ticket status:', error);
        useAlert(t('TICKETS.KANBAN.STATUS_UPDATE_ERROR'));
      }
    };

    const handleTicketClick = (ticket) => {
      emit('ticket-click', ticket);
    };

    return {
      // Computed
      notDoneTickets,
      inProgressTickets,
      escalatedTickets,
      doneTickets,
      
      // Methods
      handleTicketMove,
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
