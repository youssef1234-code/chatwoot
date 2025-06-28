<template>
  <div
    class="p-4 bg-white dark:bg-n-slate-2 rounded-lg border border-n-weak hover:border-n-strong transition-all duration-200 group relative overflow-visible"
    :class="{
      'opacity-50 transform rotate-1 scale-95 shadow-xl': isDragging,
      'hover:shadow-md': !isDragging,
      'cursor-pointer': !isDragging,
    }"
    @click="handleCardClick"
  >
    <!-- Enhanced Drag Handle - More prominent and always visible -->
    <div
      v-if="draggable"
      class="absolute -left-3 top-0 bottom-0 w-6 flex items-center justify-center cursor-grab hover:bg-blue-50 transition-all duration-200 rounded-l-lg group/drag drag-handle"
      :class="{
        'cursor-grabbing bg-blue-100': isDragging,
        'opacity-60 hover:opacity-100': !isDragging,
      }"
      @dragstart="handleDragStart"
      @dragend="handleDragEnd"
      @keydown="handleKeyDown"
      draggable="true"
      tabindex="0"
      role="button"
      :aria-label="`Drag ticket ${ticket.id} to move between columns`"
      title="Drag to move ticket between columns (or press Enter for options)"
    >
      <!-- Drag icon - always visible -->
      <div
        class="flex flex-col items-center gap-0.5 transition-all duration-200 group-hover/drag:scale-110 drag-dots"
      >
        <div
          class="w-1 h-1 bg-blue-400 rounded-full group-hover/drag:bg-blue-600"
        ></div>
        <div
          class="w-1 h-1 bg-blue-400 rounded-full group-hover/drag:bg-blue-600"
        ></div>
        <div
          class="w-1 h-1 bg-blue-400 rounded-full group-hover/drag:bg-blue-600"
        ></div>
        <div
          class="w-1 h-1 bg-blue-400 rounded-full group-hover/drag:bg-blue-600"
        ></div>
        <div
          class="w-1 h-1 bg-blue-400 rounded-full group-hover/drag:bg-blue-600"
        ></div>
        <div
          class="w-1 h-1 bg-blue-400 rounded-full group-hover/drag:bg-blue-600"
        ></div>
      </div>

      <!-- Hover hint -->
      <div
        class="absolute left-full ml-2 top-1/2 transform -translate-y-1/2 bg-gray-900 text-white text-xs px-2 py-1 rounded opacity-0 group-hover/drag:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-50"
      >
        Drag to move
        <div
          class="absolute left-0 top-1/2 transform -translate-x-1 -translate-y-1/2 w-0 h-0 border-t-2 border-b-2 border-r-4 border-transparent border-r-gray-900"
        ></div>
      </div>
    </div>
    <!-- Header -->
    <div class="flex items-start justify-between mb-3">
      <div class="flex items-center gap-2">
        <div
          class="w-2 h-2 rounded-full"
          :class="getPriorityColor(ticket.priority)"
        />
        <span class="text-xs font-mono text-purple-700 dark:text-purple-300">
          #{{ ticket.id }}
        </span>
      </div>

      <!-- Actions Menu -->
      <div
        class="relative opacity-0 group-hover:opacity-100 transition-opacity"
      >
        <NextButton
          variant="ghost"
          size="xs"
          @click.stop="showActionsMenu = !showActionsMenu"
        >
          <Icon icon="i-lucide-more-horizontal" class="w-4 h-4" />
        </NextButton>

        <!-- Actions Dropdown -->
        <div
          v-if="showActionsMenu"
          v-on-clickaway="() => (showActionsMenu = false)"
          class="absolute right-0 top-full mt-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg shadow-lg z-10 py-1 min-w-40"
        >
          <button
            class="w-full px-3 py-2 text-sm text-left hover:bg-n-alpha-1 flex items-center gap-2"
            @click.stop="$emit('enhance-with-ai')"
          >
            <Icon icon="i-lucide-sparkles" class="w-4 h-4" />
            {{ $t("TICKETS.ACTIONS.ENHANCE_WITH_AI") }}
          </button>
          <button
            class="w-full px-3 py-2 text-sm text-left hover:bg-n-alpha-1 flex items-center gap-2"
            @click.stop="openInConversation"
          >
            <Icon icon="i-lucide-external-link" class="w-4 h-4" />
            {{ $t("TICKETS.ACTIONS.OPEN_CONVERSATION") }}
          </button>
        </div>
      </div>
    </div>

    <!-- Title -->
    <h4 class="font-medium text-n-slate-12 mb-2 line-clamp-2 leading-snug">
      {{ ticket.title || $t("TICKETS.UNTITLED") }}
    </h4>

    <!-- Description -->
    <p
      v-if="ticket.description"
      class="text-sm text-n-slate-10 mb-3 line-clamp-2"
    >
      {{ ticket.description }}
    </p>

    <!-- Status Badges -->
    <div class="flex flex-wrap gap-2 mb-3">
      <span
        class="px-2 py-1 text-xs font-medium rounded-full border"
        :class="getStatusColor(effectiveStatus)"
      >
        {{ $t(`TICKETS.STATUS.${effectiveStatus?.toUpperCase()}`) }}
      </span>

      <span
        class="px-2 py-1 text-xs font-medium rounded-full border"
        :class="getPriorityBadgeColor(ticket.priority)"
      >
        {{ $t(`TICKETS.PRIORITY.${ticket.priority?.toUpperCase()}`) }}
      </span>

      <span
        v-if="ticket.category"
        class="px-2 py-1 text-xs font-medium rounded-full border bg-purple-50 text-purple-700 border-purple-200 dark:bg-purple-900/20 dark:text-purple-300 dark:border-purple-800"
      >
        {{ ticket.category }}
      </span>
    </div>

    <!-- JIRA Integration -->
    <div
      v-if="ticket.jira_issue_key"
      class="mb-3 p-2 bg-blue-50 dark:bg-blue-900/20 rounded border border-blue-200 dark:border-blue-800"
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <Icon icon="i-lucide-external-link" class="w-4 h-4 text-blue-600" />
          <span class="text-sm font-medium text-blue-800 dark:text-blue-200">
            {{ ticket.jira_issue_key }}
          </span>
        </div>
        <NextButton
          variant="ghost"
          size="xs"
          color="blue"
          @click.stop="openJiraIssue"
        >
          {{ $t("TICKETS.VIEW_IN_JIRA") }}
        </NextButton>
      </div>

      <!-- JIRA Status -->
      <div
        v-if="jiraStatus"
        class="mt-2 text-xs text-blue-700 dark:text-blue-300"
      >
        JIRA Status: {{ jiraStatus }}
      </div>
    </div>

    <!-- Conversation Link -->
    <div class="mb-3">
      <div class="flex items-center gap-2 text-sm text-n-slate-9">
        <Icon icon="i-lucide-message-circle" class="w-4 h-4" />
        <span>{{ $t("TICKETS.CONVERSATION") }}</span>
        <span class="font-mono text-xs"
          >#{{ ticket.conversation?.id }}</span
        >
      </div>
    </div>

    <!-- Customer Info -->
    <div v-if="customerInfo" class="mb-3">
      <div class="flex items-center gap-2 text-sm text-n-slate-9 mb-1">
        <Icon icon="i-lucide-user" class="w-4 h-4" />
        <span class="font-medium">{{ customerInfo.name }}</span>
      </div>
      <div
        v-if="customerInfo.organization"
        class="flex items-center gap-2 text-xs text-purple-700 dark:text-purple-400 ml-6 bg-purple-50 dark:bg-purple-900/20 px-2 py-1 rounded"
      >
        <Icon icon="i-lucide-building" class="w-3 h-3" />
        <span class="font-medium">{{ customerInfo.organization }}</span>
      </div>
    </div>

    <!-- Messages Count -->
    <div class="mb-3">
      <div class="flex items-center gap-2 text-sm text-n-slate-9">
        <Icon icon="i-lucide-messages-square" class="w-4 h-4" />
        <span
          >{{ ticket.message_count || 0 }} {{ $t("TICKETS.MESSAGES") }}</span
        >
      </div>
    </div>

    <!-- Footer -->
    <div class="flex items-center justify-between text-xs text-n-slate-8">
      <!-- Assigned Agent -->
      <div class="flex items-center gap-2">
        <div v-if="ticket.assigned_agent" class="flex items-center gap-2">
          <div
            class="w-6 h-6 rounded-full bg-n-alpha-2 flex items-center justify-center"
          >
            {{ getInitials(ticket.assigned_agent.name) }}
          </div>
          <span>{{ ticket.assigned_agent.name }}</span>
        </div>
        <span v-else class="text-n-slate-7">{{
          $t("TICKETS.UNASSIGNED")
        }}</span>
      </div>

      <!-- Created Date -->
      <span>{{ formatDate(ticket.created_at) }}</span>
    </div>
  </div>
</template>

<script>
import { ref, computed } from "vue";
import { useI18n } from "vue-i18n";
import { useRouter } from "vue-router";
import { formatDistanceToNow } from "date-fns";
import { useDragState } from "dashboard/composables/useDragState";
import NextButton from "dashboard/components-next/button/Button.vue";
import Icon from "dashboard/components-next/icon/Icon.vue";

export default {
  name: "TicketCard",
  components: {
    NextButton,
    Icon,
  },
  props: {
    ticket: {
      type: Object,
      required: true,
    },
    color: {
      type: String,
      default: "blue",
    },
    draggable: {
      type: Boolean,
      default: true,
    },
  },
  emits: ["click", "enhance-with-ai", "dragstart", "dragend"],
  setup(props, { emit }) {
    const { t } = useI18n();
    const router = useRouter();

    // State
    const isDragging = ref(false);
    const showActionsMenu = ref(false);
    const dragStartTime = ref(0);

    // Computed
    const customerInfo = computed(() => {
      if (!props.ticket.contact) return null;

      return {
        name:
          props.ticket.contact.name ||
          props.ticket.created_by?.name ||
          "Unknown Customer",
        organization:
          props.ticket.contact.company || props.ticket.contact.organization,
      };
    });

    const jiraStatus = computed(() => {
      // This would come from JIRA integration data
      return props.ticket.jira_status || null;
    });

    // Compute the effective status - prioritize in_progress
    const effectiveStatus = computed(() => {
      // If ticket status is in_progress, show it
      if (props.ticket.status === "in_progress") {
        return "in_progress";
      }

      // If ticket is actively being worked on in JIRA, show in_progress
      if (
        props.ticket.jira_in_progress &&
        props.ticket.status !== "resolved" &&
        props.ticket.status !== "closed"
      ) {
        return "in_progress";
      }

      // Otherwise, show the actual status
      return props.ticket.status;
    });

    // Methods
    const getStatusColor = (status) => {
      const colors = {
        open: "bg-blue-50 text-blue-700 border-blue-200",
        in_progress: "bg-yellow-50 text-yellow-700 border-yellow-200",
        escalated: "bg-orange-50 text-orange-700 border-orange-200",
        resolved: "bg-green-50 text-green-700 border-green-200",
        closed: "bg-gray-50 text-gray-700 border-gray-200",
      };
      return colors[status] || colors.open;
    };

    const getPriorityColor = (priority) => {
      const colors = {
        low: "bg-green-400",
        medium: "bg-yellow-400",
        high: "bg-orange-400",
        urgent: "bg-red-500",
      };
      return colors[priority] || colors.medium;
    };

    const getPriorityBadgeColor = (priority) => {
      const colors = {
        low: "bg-green-50 text-green-700 border-green-200",
        medium: "bg-yellow-50 text-yellow-700 border-yellow-200",
        high: "bg-orange-50 text-orange-700 border-orange-200",
        urgent: "bg-red-50 text-red-700 border-red-200",
      };
      return colors[priority] || colors.medium;
    };

    const getInitials = (name) => {
      return (
        name
          ?.split(" ")
          .map((word) => word[0])
          .join("")
          .toUpperCase()
          .slice(0, 2) || "??"
      );
    };

    const formatDate = (dateString) => {
      if (!dateString) return "";
      try {
        return formatDistanceToNow(new Date(dateString), { addSuffix: true });
      } catch (error) {
        return "";
      }
    };

    const handleDragStart = (event) => {
      // Only handle dragstart events
      if (event.type !== "dragstart" || !event.dataTransfer) {
        return;
      }

      console.log("TicketCard: Drag started for ticket:", props.ticket.id);

      // Set global drag state
      const { setDraggedTicket } = useDragState();
      setDraggedTicket(props.ticket);

      isDragging.value = true;
      dragStartTime.value = Date.now();

      // Set drag data
      event.dataTransfer.setData("ticket", JSON.stringify(props.ticket));
      event.dataTransfer.setData("text/plain", `Ticket #${props.ticket.id}`);
      event.dataTransfer.effectAllowed = "move";

      // Prevent the default ghost image and create custom one
      const dragImage = document.createElement("div");
      dragImage.innerHTML = `
        <div style="
          background: white; 
          border: 2px solid #3b82f6; 
          border-radius: 8px; 
          padding: 12px; 
          box-shadow: 0 10px 25px rgba(0,0,0,0.15);
          font-family: system-ui;
          font-size: 14px;
          max-width: 300px;
          opacity: 0.9;
        ">
          <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 8px;">
            <div style="width: 8px; height: 8px; background: #3b82f6; border-radius: 50%;"></div>
            <span style="font-weight: 600; color: #1f2937;">#${props.ticket.id}</span>
          </div>
          <div style="color: #374151; font-weight: 500; margin-bottom: 4px;">${props.ticket.title || "Untitled"}</div>
          <div style="color: #6b7280; font-size: 12px;">Drag to resolve or escalate</div>
        </div>
      `;
      dragImage.style.position = "absolute";
      dragImage.style.top = "-1000px";
      dragImage.style.left = "-1000px";
      document.body.appendChild(dragImage);

      event.dataTransfer.setDragImage(dragImage, 150, 50);

      // Clean up drag image
      setTimeout(() => {
        if (document.body.contains(dragImage)) {
          document.body.removeChild(dragImage);
        }
      }, 100);

      emit("dragstart", event);
    };

    const handleDragEnd = (event) => {
      console.log("TicketCard: Drag ended for ticket:", props.ticket.id);

      // Clear global drag state
      const { clearDraggedTicket } = useDragState();
      clearDraggedTicket();

      setTimeout(() => {
        isDragging.value = false;
      }, 100);

      emit("dragend", event);
    };

    const handleCardClick = (event) => {
      // Prevent click if we just finished dragging
      const timeSinceDrag = Date.now() - dragStartTime.value;
      if (isDragging.value || timeSinceDrag < 200) {
        event.preventDefault();
        event.stopPropagation();
        return;
      }

      emit("click");
    };

    const handleKeyDown = (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        // Show a context menu or quick actions for keyboard users
        showActionsMenu.value = !showActionsMenu.value;
      }
    };

    const openInConversation = () => {
      if (props.ticket.conversation?.id) {
        const accountId = router.currentRoute.value.params.accountId;
        const conversationUrl = `/app/accounts/${accountId}/conversations/${props.ticket.conversation.id}`;
        window.open(conversationUrl, "_blank");
      }
    };

    const openJiraIssue = () => {
      if (props.ticket.jira_url) {
        window.open(props.ticket.jira_url, "_blank");
      } else if (props.ticket.jira_issue_key) {
        // Construct JIRA URL from issue key (you may need to adjust this based on your JIRA instance)
        const jiraBaseUrl =
          window.chatwootConfig?.jiraBaseUrl ||
          "https://your-domain.atlassian.net";
        const jiraUrl = `${jiraBaseUrl}/browse/${props.ticket.jira_issue_key}`;
        window.open(jiraUrl, "_blank");
      }
    };

    return {
      // State
      isDragging,
      showActionsMenu,
      dragStartTime,

      // Computed
      customerInfo,
      jiraStatus,
      effectiveStatus,

      // Methods
      getStatusColor,
      getPriorityColor,
      getPriorityBadgeColor,
      getInitials,
      formatDate,
      handleDragStart,
      handleDragEnd,
      handleCardClick,
      handleKeyDown,
      openInConversation,
      openJiraIssue,
    };
  },
};
</script>

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

/* Drag effects */
.cursor-grab {
  cursor: grab;
}

.cursor-grabbing {
  cursor: grabbing;
}

/* Enhanced drag handle styles */
.group\/drag:hover {
  background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
}

.group\/drag:active {
  background: linear-gradient(135deg, #bfdbfe 0%, #93c5fd 100%);
}

/* Improved drag detection */
.group\/drag {
  touch-action: none;
  user-select: none;
  -webkit-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
}

/* Better visual feedback */
.group\/drag:hover .drag-dots {
  transform: scale(1.2);
}

/* Subtle pulse animation for drag handle discovery */
@keyframes dragHintPulse {
  0%,
  100% {
    opacity: 0.6;
  }
  50% {
    opacity: 1;
  }
}

.drag-handle {
  animation: dragHintPulse 3s ease-in-out infinite;
}

/* Smooth transitions */
* {
  transition: all 0.2s ease;
}
</style>
