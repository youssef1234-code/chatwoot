<template>
  <div class="flex h-full overflow-x-auto gap-6 min-h-96 p-6 relative">
    <!-- Loading overlay for actions -->
    <div
      v-if="isResolving || isEscalating"
      class="absolute inset-0 bg-black bg-opacity-20 backdrop-blur-sm flex items-center justify-center z-50"
    >
      <div class="bg-white rounded-lg shadow-xl p-6 flex items-center gap-4">
        <Icon
          icon="i-lucide-loader-2"
          class="w-6 h-6 animate-spin text-blue-600"
        />
        <span class="font-medium">
          {{
            isResolving
              ? $t("TICKETS.KANBAN.RESOLVING")
              : $t("TICKETS.KANBAN.ESCALATING")
          }}
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
      :can-accept-drop="canAcceptDrop"
      class="flex-1 min-w-80"
      @ticket-move="handleTicketMove"
      @ticket-click="handleTicketClick"
      @ticket-deleted="handleTicketDeleted"
    />

    <!-- Escalation Modal -->
    <EscalateToJiraModal
      v-if="showEscalationModal"
      :ticket="ticketToEscalate"
      @close="handleEscalationModalClose"
      @escalated="handleEscalationConfirm"
    />
  </div>
</template>

<script>
import { computed, ref, watch, onMounted, onUnmounted } from "vue";
import { useStore } from "vuex";
import { useI18n } from "vue-i18n";
import { emitter } from "shared/helpers/mitt";

import KanbanColumn from "./KanbanColumn.vue";
import EscalateToJiraModal from "dashboard/components/tickets/EscalateToJiraModal.vue";
import Icon from "dashboard/components-next/icon/Icon.vue";

import { useAlert } from "dashboard/composables";

export default {
  name: "TicketsKanbanBoard",
  components: {
    KanbanColumn,
    EscalateToJiraModal,
    Icon,
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
    selectedStatuses: {
      type: Array,
      default: () => [],
    },
  },
  emits: [
    "ticket-updated",
    "refresh",
    "ticket-click",
    "ticket-escalate",
    "ticket-deleted",
  ],
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
      const tickets = props.tickets.filter((ticket) => ticket.status === "open");
      // Sort by ID in descending order (newest first)
      return tickets.sort((a, b) => b.id - a.id);
    });

    const inProgressTickets = computed(() => {
      const tickets = props.tickets.filter((ticket) => {
        // Explicitly in progress status takes priority - even if escalated
        if (ticket.status === "in_progress") {
          return true;
        }

        // JIRA linked tickets that are actively being worked on
        // Higher priority: if jira_in_progress is true, show here regardless of escalation
        if (
          ticket.jira_in_progress &&
          ticket.status !== "resolved" &&
          ticket.status !== "closed"
        ) {
          return true;
        }

        return false;
      });
      // Sort by ID in descending order (newest first)
      return tickets.sort((a, b) => b.id - a.id);
    });

    console.log("PROPS TICKETS:", props.tickets);

    const escalatedTickets = computed(() => {
      const tickets = props.tickets.filter((ticket) => {
        // Only show escalated status tickets that are NOT in progress or actively worked on in JIRA
        return (
          ticket.status === "escalated" &&
          ticket.status !== "in_progress" &&
          !ticket.jira_in_progress
        );
      });
      // Sort by ID in descending order (newest first)
      return tickets.sort((a, b) => b.id - a.id);
    });

    const doneTickets = computed(() => {
      const tickets = props.tickets.filter(
        (ticket) =>
          ticket.status === "resolved" ||
          ticket.status === "closed" ||
          ticket.status === "done"
      );
      // Sort by ID in descending order (newest first)
      return tickets.sort((a, b) => b.id - a.id);
    });

    // Define all possible columns
    const allColumns = computed(() => [
      {
        key: "not_done",
        title: t("TICKETS.KANBAN.NOT_DONE"),
        status: "not_done",
        color: "blue",
        tickets: notDoneTickets.value,
        statusFilters: ["open"],
      },
      {
        key: "escalated",
        title: t("TICKETS.KANBAN.ESCALATED"),
        status: "escalated",
        color: "orange",
        tickets: escalatedTickets.value,
        statusFilters: ["escalated"],
      },
      {
        key: "in_progress",
        title: t("TICKETS.KANBAN.IN_PROGRESS"),
        status: "in_progress",
        color: "yellow",
        tickets: inProgressTickets.value,
        statusFilters: ["in_progress"],
      },
      {
        key: "done",
        title: t("TICKETS.KANBAN.DONE"),
        status: "done",
        color: "green",
        tickets: doneTickets.value,
        statusFilters: ["resolved", "closed"],
      },
    ]);

    // Show only columns that match selected statuses, or all if none selected
    const visibleColumns = computed(() => {
      if (props.selectedStatuses.length === 0) {
        return allColumns.value;
      }

      return allColumns.value.filter((column) =>
        column.statusFilters.some((status) =>
          props.selectedStatuses.includes(status)
        )
      );
    });

    // Methods
    const isValidTransition = (ticket, newStatus) => {
      const currentStatus = getTicketDisplayStatus(ticket);

      console.log("Checking transition:", {
        ticketId: ticket.id,
        currentStatus,
        newStatus,
        actualTicketStatus: ticket.status,
        jiraInProgress: ticket.jira_in_progress,
      });

      // Only allow transitions from 'not_done' to 'done' or 'escalated'
      if (currentStatus === "not_done") {
        const isValid = newStatus === "done" || newStatus === "escalated";
        console.log("Transition validation result:", isValid);
        return isValid;
      }

      // No other transitions are allowed
      console.log("Transition blocked - not from not_done status");
      return false;
    };

    const getTicketDisplayStatus = (ticket) => {
      // Priority: jira_in_progress > escalated > resolved/closed > open
      if (ticket.status === "in_progress" || ticket.jira_in_progress) {
        return "in_progress";
      }
      if (ticket.status === "escalated" || ticket.jira_issue_key) {
        return "escalated";
      }
      if (ticket.status === "resolved" || ticket.status === "closed") {
        return "done";
      }
      return "not_done"; // open, in_progress without jira
    };

    const handleTicketMove = async (ticket, newStatus) => {
      console.log("handleTicketMove called:", {
        ticket: ticket.id,
        newStatus,
        currentStatus: ticket.status,
      });

      // Check if the transition is valid
      if (!isValidTransition(ticket, newStatus)) {
        const currentStatus = getTicketDisplayStatus(ticket);
        useAlert(
          t("TICKETS.KANBAN.INVALID_TRANSITION", {
            from: t(`TICKETS.KANBAN.${currentStatus.toUpperCase()}`),
            to: t(`TICKETS.KANBAN.${newStatus.toUpperCase()}`),
          })
        );
        return false;
      }

      try {
        if (newStatus === "done") {
          // Show loading state and resolve ticket
          isResolving.value = true;
          await store.dispatch("tickets/resolve", ticket.id);
          emit("ticket-updated");
          emit("refresh"); // Also emit refresh to reload data
          useAlert(t("TICKETS.KANBAN.TICKET_RESOLVED"));
          return true;
        } else if (newStatus === "escalated") {
          // Show escalation modal
          ticketToEscalate.value = ticket;
          showEscalationModal.value = true;
          // Don't return true yet - wait for modal confirmation
          return null; // Indicates pending action
        }

        return true;
      } catch (error) {
        console.error("Failed to update ticket status:", error);
        useAlert(t("TICKETS.KANBAN.STATUS_UPDATE_ERROR"));
        return false;
      } finally {
        isResolving.value = false;
      }
    };

    const handleEscalationModalClose = () => {
      showEscalationModal.value = false;
      ticketToEscalate.value = null;
    };

    const handleEscalationConfirm = async (escalationData) => {
      try {
        // The EscalateToJiraModal already handles the escalation process
        // escalationData contains { jiraIssueKey }
        console.log("Escalation completed:", escalationData);

        emit("ticket-updated");
        emit("refresh"); // Also emit refresh to reload data
        useAlert(t("TICKETS.KANBAN.ESCALATION_INITIATED"));
        handleEscalationModalClose();
      } catch (error) {
        console.error("Failed to handle escalation completion:", error);
        useAlert(t("TICKETS.KANBAN.STATUS_UPDATE_ERROR"));
      } finally {
        isEscalating.value = false;
      }
    };

    const handleTicketClick = (ticket) => {
      emit("ticket-click", ticket);
    };

    const handleTicketDeleted = (ticketId) => {
      // The ticket should already be removed from the store by the delete action
      // This handler can be used for any additional UI cleanup if needed
      console.log("Ticket deleted:", ticketId);
    };

    // WebSocket event handlers for real-time updates
    const handleTicketDeletedEvent = (data) => {
      console.log('KanbanBoard: Received ticket deleted event', data);
      // The ticket should already be removed from the store,
      // but we can emit refresh to ensure UI is up to date
      emit("refresh");
    };

    // Setup WebSocket listeners
    onMounted(() => {
      emitter.on('tickets:ticket-deleted', handleTicketDeletedEvent);
    });

    onUnmounted(() => {
      emitter.off('tickets:ticket-deleted', handleTicketDeletedEvent);
    });

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
      handleTicketDeleted,
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
