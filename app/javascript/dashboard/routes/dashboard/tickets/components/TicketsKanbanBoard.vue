<template>
  <div class="flex flex-col h-full">
    <!-- Kanban Columns -->
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
        :is-loading="columnLoadingStates[column.key]"
        :status="column.status"
        :color="column.color"
        :has-more="columnHasMore[column.key]"
        :can-accept-drop="canAcceptDrop"
        class="flex-1 min-w-80"
        @ticket-move="handleTicketMove"
        @ticket-click="handleTicketClick"
        @ticket-deleted="handleTicketDeleted"
        @load-more="() => loadMoreTickets(column.key)"
      />

      <!-- Escalation Modal -->
      <EscalateToJiraModal
        v-if="showEscalationModal"
        :ticket="ticketToEscalate"
        @close="handleEscalationModalClose"
        @escalated="handleEscalationConfirm"
      />
    </div>
  </div>
</template>

<script>
import { computed, ref, watch, onMounted, onUnmounted, reactive } from "vue";
import { useStore } from "vuex";
import { useI18n } from "vue-i18n";
import { emitter } from "shared/helpers/mitt";

import KanbanColumn from "./KanbanColumn.vue";
import EscalateToJiraModal from "dashboard/components/tickets/EscalateToJiraModal.vue";
import Icon from "dashboard/components-next/icon/Icon.vue";
import TicketsAPI from "dashboard/api/tickets";
import PlaneAPI from "dashboard/api/integrations/plane";

import { useAlert } from "dashboard/composables";
import { useFunctionGetter } from "dashboard/composables/store";

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
    usePagination: {
      type: Boolean,
      default: false,
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
    
    // Plane integration state
    const planeIntegration = useFunctionGetter('integrations/getIntegration', 'plane');
    const isPlaneEnabled = computed(() => planeIntegration.value?.enabled || false);
    const planeStates = ref([]);
    
    // Dynamic pagination state — initialized with base columns, extras added after fetching Plane states
    const columnTickets = reactive({});
    const columnCursors = reactive({});
    const columnHasMore = reactive({});
    const columnLoadingStates = reactive({});

    // Base columns (always shown)
    const BASE_COLUMNS = [
      { key: 'not_done', title: t('TICKETS.KANBAN.NOT_DONE'), status: 'not_done', color: 'blue', statusFilters: ['open'], statusParam: 'open' },
      { key: 'escalated', title: t('TICKETS.KANBAN.ESCALATED'), status: 'escalated', color: 'orange', statusFilters: ['escalated'], statusParam: 'escalated' },
      { key: 'in_progress', title: t('TICKETS.KANBAN.IN_PROGRESS'), status: 'in_progress', color: 'yellow', statusFilters: ['in_progress'], statusParam: 'in_progress' },
      { key: 'done', title: t('TICKETS.KANBAN.DONE'), status: 'done', color: 'green', statusFilters: ['resolved', 'closed'], statusParam: 'resolved,closed' },
    ];
    
    // Base state names that map to our 4 base columns (case-insensitive match)
    const BASE_STATE_GROUPS = {
      backlog: 'not_done',
      unstarted: 'not_done',
      started: 'in_progress',
      completed: 'done',
      cancelled: 'done',
    };

    // Initialize pagination state for base columns
    BASE_COLUMNS.forEach(col => {
      columnTickets[col.key] = [];
      columnCursors[col.key] = null;
      columnHasMore[col.key] = true;
      columnLoadingStates[col.key] = false;
    });

    // Extra Plane state columns (dynamically built after fetching states)
    const extraPlaneColumns = ref([]);

    // Analytics state
    const analytics = ref(null);

    // Computed - Analytics stats for header (dynamic based on columns)
    const analyticsStats = computed(() => {
      if (!analytics.value) return [];

      const baseStats = [
        { key: 'open', label: t('TICKETS.KANBAN.NOT_DONE'), count: analytics.value.not_done || analytics.value.open || 0, colorClass: 'bg-blue-500' },
        { key: 'escalated', label: t('TICKETS.KANBAN.ESCALATED'), count: analytics.value.escalated || 0, colorClass: 'bg-orange-500' },
        { key: 'in_progress', label: t('TICKETS.KANBAN.IN_PROGRESS'), count: analytics.value.in_progress || 0, colorClass: 'bg-yellow-500' },
        { key: 'done', label: t('TICKETS.KANBAN.DONE'), count: analytics.value.done || (analytics.value.resolved || 0) + (analytics.value.closed || 0), colorClass: 'bg-green-500' },
      ];

      // Add dynamic Plane state stats
      const byPlaneState = analytics.value.by_plane_state || {};
      extraPlaneColumns.value.forEach(col => {
        baseStats.push({
          key: col.key,
          label: col.title,
          count: byPlaneState[col.planeStateName] || 0,
          colorStyle: col.planeStateColor ? { backgroundColor: col.planeStateColor } : null,
          colorClass: col.planeStateColor ? '' : 'bg-purple-500',
        });
      });

      return baseStats;
    });

    // Load analytics
    const loadAnalytics = async () => {
      try {
        const response = await TicketsAPI.getAnalytics({
          assigned_agent_id: props.currentUser?.id,
        });
        analytics.value = response.data;
      } catch (error) {
        console.error('Failed to load analytics:', error);
      }
    };

    // Load Plane states and create extra dynamic columns
    const loadPlaneStates = async () => {
      if (!isPlaneEnabled.value) return;

      try {
        const response = await PlaneAPI.getPlaneStatuses();
        const states = response.data?.states || [];
        planeStates.value = states;

        // Find states that don't map to our base columns
        const extras = [];
        states.forEach(state => {
          const group = (state.group || '').toLowerCase();
          // If this state's group maps to a base column, skip it
          if (BASE_STATE_GROUPS[group]) return;

          // Check if name exactly matches a base column
          const nameLower = state.name.toLowerCase().trim();
          const matchesBase = ['open', 'escalated', 'in progress', 'in_progress', 'done', 'resolved', 'closed', 'backlog', 'todo', 'to do'].includes(nameLower);
          if (matchesBase) return;

          const safeKey = `plane_${nameLower.replace(/\s+/g, '_')}`;
          extras.push({
            key: safeKey,
            title: state.name,
            status: safeKey,
            color: 'purple',
            planeStateName: state.name,
            planeStateColor: state.color || '#94a3b8',
            statusFilters: [safeKey],
            isPlaneState: true,
          });
        });

        extraPlaneColumns.value = extras;

        // Initialize pagination state for extra columns
        extras.forEach(col => {
          if (!columnTickets[col.key]) {
            columnTickets[col.key] = [];
            columnCursors[col.key] = null;
            columnHasMore[col.key] = true;
            columnLoadingStates[col.key] = false;
          }
        });
      } catch (error) {
        console.error('Failed to load Plane states:', error);
      }
    };

    // Load tickets for a specific column using pagination
    const loadColumnTickets = async (columnKey, reset = false) => {
      if (columnLoadingStates[columnKey] || (!columnHasMore[columnKey] && !reset)) {
        return;
      }

      columnLoadingStates[columnKey] = true;
      
      try {
        // Find the column definition
        const allCols = [...BASE_COLUMNS, ...extraPlaneColumns.value];
        const column = allCols.find(c => c.key === columnKey);

        const params = {
          limit: 20,
          assigned_agent_id: props.currentUser?.id,
        };

        if (column?.isPlaneState) {
          // Dynamic Plane state column — filter by plane_state
          params.plane_state = column.planeStateName;
        } else if (column?.statusParam) {
          params.status = column.statusParam;
        }

        if (!reset && columnCursors[columnKey]) {
          params.cursor = columnCursors[columnKey];
        }

        const response = await TicketsAPI.getKanban(params);
        const { tickets, next_cursor, has_more } = response.data;

        if (reset) {
          columnTickets[columnKey] = tickets;
        } else {
          columnTickets[columnKey] = [...columnTickets[columnKey], ...tickets];
        }
        
        columnCursors[columnKey] = next_cursor;
        columnHasMore[columnKey] = has_more;
      } catch (error) {
        console.error(`Failed to load tickets for ${columnKey}:`, error);
      } finally {
        columnLoadingStates[columnKey] = false;
      }
    };

    const loadMoreTickets = (columnKey) => {
      if (props.usePagination) {
        loadColumnTickets(columnKey, false);
      }
    };

    // Computed - Organize tickets by status (for non-paginated mode)
    const notDoneTickets = computed(() => {
      if (props.usePagination) return columnTickets.not_done || [];
      const tickets = props.tickets.filter((ticket) => ticket.status === "open");
      return tickets.sort((a, b) => b.id - a.id);
    });

    const inProgressTickets = computed(() => {
      if (props.usePagination) return columnTickets.in_progress || [];
      const tickets = props.tickets.filter((ticket) => {
        if (ticket.status === "in_progress") return true;
        if (ticket.jira_in_progress && ticket.status !== "resolved" && ticket.status !== "closed") return true;
        return false;
      });
      return tickets.sort((a, b) => b.id - a.id);
    });

    const escalatedTickets = computed(() => {
      if (props.usePagination) return columnTickets.escalated || [];
      const tickets = props.tickets.filter((ticket) => {
        return ticket.status === "escalated" && ticket.status !== "in_progress" && !ticket.jira_in_progress;
      });
      return tickets.sort((a, b) => b.id - a.id);
    });

    const doneTickets = computed(() => {
      if (props.usePagination) return columnTickets.done || [];
      const tickets = props.tickets.filter((ticket) =>
        ticket.status === "resolved" || ticket.status === "closed" || ticket.status === "done"
      );
      return tickets.sort((a, b) => b.id - a.id);
    });

    // Dynamic Plane state ticket getters (for non-paginated mode)
    const getPlaneStateTickets = (planeStateName) => {
      if (props.usePagination) {
        const safeKey = `plane_${planeStateName.toLowerCase().replace(/\s+/g, '_')}`;
        return columnTickets[safeKey] || [];
      }
      return props.tickets.filter(t => t.plane_state && t.plane_state.toLowerCase() === planeStateName.toLowerCase())
                          .sort((a, b) => b.id - a.id);
    };

    // Define all possible columns (dynamic)
    const allColumns = computed(() => {
      const base = [
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
      ];

      // Add dynamic Plane state columns after Done
      extraPlaneColumns.value.forEach(col => {
        base.push({
          ...col,
          tickets: getPlaneStateTickets(col.planeStateName),
        });
      });

      return base;
    });

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

    // Function to determine if a drop is allowed for a ticket on a specific column
    const canAcceptDrop = (ticket, targetStatus) => {
      const currentStatus = getTicketDisplayStatus(ticket);
      
      // Only allow transitions from 'not_done' to 'done' or 'escalated'
      if (currentStatus === "not_done") {
        return targetStatus === "done" || targetStatus === "escalated";
      }
      
      return false;
    };

    // WebSocket event handlers for real-time updates
    const handleTicketDeletedEvent = (data) => {
      console.log('KanbanBoard: Received ticket deleted event', data);
      emit("refresh");
    };

    // Setup WebSocket listeners and load analytics
    onMounted(async () => {
      emitter.on('tickets:ticket-deleted', handleTicketDeletedEvent);
      loadAnalytics();
      
      // Fetch Plane states for dynamic columns
      await loadPlaneStates();
      
      // If using pagination, load initial tickets for each column
      if (props.usePagination) {
        const allCols = [...BASE_COLUMNS, ...extraPlaneColumns.value];
        allCols.forEach(col => {
          loadColumnTickets(col.key, true);
        });
      }
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
      analytics,
      columnLoadingStates,
      columnHasMore,
      planeStates,
      extraPlaneColumns,
      isPlaneEnabled,

      // Computed
      analyticsStats,
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
      loadMoreTickets,
      loadAnalytics,
      loadPlaneStates,
      canAcceptDrop,
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
