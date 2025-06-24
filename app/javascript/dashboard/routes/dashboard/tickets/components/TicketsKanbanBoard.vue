<template>
  <div class="flex h-full overflow-x-auto gap-6 min-h-96 p-6">
    <KanbanColumn
      v-for="column in visibleColumns"
      :key="column.key"
      :title="column.title"
      :tickets="column.tickets"
      :is-loading="isLoading"
      :status="column.status"
      :color="column.color"
      class="flex-1 min-w-80"
      @ticket-move="handleTicketMove"
      @ticket-click="handleTicketClick"
      @enhance-with-ai="$emit('enhance-with-ai', $event)"
    />
  </div>
</template>

<script>
import { computed, ref, watch } from 'vue';
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
    selectedStatuses: {
      type: Array,
      default: () => [],
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
          // For escalation, automatically create and link JIRA issue
          try {
            // Import JIRA API
            const JiraAPI = await import('dashboard/api/integrations/jira');
            
            // Create JIRA issue automatically
            const jiraResponse = await JiraAPI.default.createIssue({
              summary: ticket.title || `Ticket #${ticket.id}`,
              description: ticket.description || 'No description provided',
              issueType: 'Task',
              priority: ticket.priority || 'Medium',
            });
            
            // Link the created JIRA issue to the ticket and update status
            await store.dispatch('tickets/escalateToJira', {
              ticketId: ticket.id,
              jiraIssueKey: jiraResponse.data.key,
              jiraUrl: jiraResponse.data.self,
            });
          } catch (error) {
            console.error('Failed to create JIRA issue:', error);
            // Fallback: just update status to escalated
            await store.dispatch('tickets/updateTicket', {
              id: ticket.id,
              status: targetStatus,
            });
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
      allColumns,
      visibleColumns,
      
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
