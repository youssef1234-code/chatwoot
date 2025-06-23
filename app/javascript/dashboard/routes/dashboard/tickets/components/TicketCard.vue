<template>
  <div
    class="p-4 bg-white dark:bg-n-slate-2 rounded-lg border border-n-weak hover:border-n-strong transition-all duration-200 cursor-pointer group"
    :class="{ 'opacity-50': isDragging }"
    @click="$emit('click')"
    @dragstart="handleDragStart"
    @dragend="handleDragEnd"
  >
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
      <div class="relative opacity-0 group-hover:opacity-100 transition-opacity">
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
          v-on-clickaway="() => showActionsMenu = false"
          class="absolute right-0 top-full mt-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg shadow-lg z-10 py-1 min-w-40"
        >
          <button
            class="w-full px-3 py-2 text-sm text-left hover:bg-n-alpha-1 flex items-center gap-2"
            @click.stop="$emit('enhance-with-ai')"
          >
            <Icon icon="i-lucide-sparkles" class="w-4 h-4" />
            {{ $t('TICKETS.ACTIONS.ENHANCE_WITH_AI') }}
          </button>
          <button
            class="w-full px-3 py-2 text-sm text-left hover:bg-n-alpha-1 flex items-center gap-2"
            @click.stop="openInConversation"
          >
            <Icon icon="i-lucide-external-link" class="w-4 h-4" />
            {{ $t('TICKETS.ACTIONS.OPEN_CONVERSATION') }}
          </button>
        </div>
      </div>
    </div>

    <!-- Title -->
    <h4 class="font-medium text-n-slate-12 mb-2 line-clamp-2 leading-snug">
      {{ ticket.title || $t('TICKETS.UNTITLED') }}
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
        :class="getStatusColor(ticket.status)"
      >
        {{ $t(`TICKETS.STATUS.${ticket.status?.toUpperCase()}`) }}
      </span>
      
      <span
        class="px-2 py-1 text-xs font-medium rounded-full border"
        :class="getPriorityBadgeColor(ticket.priority)"
      >
        {{ $t(`TICKETS.PRIORITY.${ticket.priority?.toUpperCase()}`) }}
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
          {{ $t('TICKETS.VIEW_IN_JIRA') }}
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
        <span>{{ $t('TICKETS.CONVERSATION') }}</span>
        <span class="font-mono text-xs">#{{ ticket.conversation?.display_id }}</span>
      </div>
    </div>

    <!-- Messages Count -->
    <div class="mb-3">
      <div class="flex items-center gap-2 text-sm text-n-slate-9">
        <Icon icon="i-lucide-messages-square" class="w-4 h-4" />
        <span>{{ ticket.message_count || 0 }} {{ $t('TICKETS.MESSAGES') }}</span>
      </div>
    </div>

    <!-- Footer -->
    <div class="flex items-center justify-between text-xs text-n-slate-8">
      <!-- Assigned Agent -->
      <div class="flex items-center gap-2">
        <div
          v-if="ticket.assigned_agent"
          class="flex items-center gap-2"
        >
          <div class="w-6 h-6 rounded-full bg-n-alpha-2 flex items-center justify-center">
            {{ getInitials(ticket.assigned_agent.name) }}
          </div>
          <span>{{ ticket.assigned_agent.name }}</span>
        </div>
        <span v-else class="text-n-slate-7">{{ $t('TICKETS.UNASSIGNED') }}</span>
      </div>

      <!-- Created Date -->
      <span>{{ formatDate(ticket.created_at) }}</span>
    </div>
  </div>
</template>

<script>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { formatDistanceToNow } from 'date-fns';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

export default {
  name: 'TicketCard',
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
      default: 'blue',
    },
    draggable: {
      type: Boolean,
      default: true,
    },
  },
  emits: ['click', 'enhance-with-ai', 'dragstart', 'dragend'],
  setup(props, { emit }) {
    const { t } = useI18n();
    const router = useRouter();

    // State
    const isDragging = ref(false);
    const showActionsMenu = ref(false);

    // Computed
    const jiraStatus = computed(() => {
      // This would come from JIRA integration data
      return props.ticket.jira_status || null;
    });

    // Methods
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
        low: 'bg-green-400',
        medium: 'bg-yellow-400',
        high: 'bg-orange-400',
        urgent: 'bg-red-500',
      };
      return colors[priority] || colors.medium;
    };

    const getPriorityBadgeColor = (priority) => {
      const colors = {
        low: 'bg-green-50 text-green-700 border-green-200',
        medium: 'bg-yellow-50 text-yellow-700 border-yellow-200',
        high: 'bg-orange-50 text-orange-700 border-orange-200',
        urgent: 'bg-red-50 text-red-700 border-red-200',
      };
      return colors[priority] || colors.medium;
    };

    const getInitials = (name) => {
      return name
        ?.split(' ')
        .map(word => word[0])
        .join('')
        .toUpperCase()
        .slice(0, 2) || '??';
    };

    const formatDate = (dateString) => {
      if (!dateString) return '';
      try {
        return formatDistanceToNow(new Date(dateString), { addSuffix: true });
      } catch (error) {
        return '';
      }
    };

    const handleDragStart = (event) => {
      isDragging.value = true;
      emit('dragstart', event);
    };

    const handleDragEnd = (event) => {
      isDragging.value = false;
      emit('dragend', event);
    };

    const openInConversation = () => {
      if (props.ticket.conversation?.id) {
        const accountId = router.currentRoute.value.params.accountId;
        const conversationUrl = `/app/accounts/${accountId}/conversations/${props.ticket.conversation.id}`;
        window.open(conversationUrl, '_blank');
      }
    };

    const openJiraIssue = () => {
      if (props.ticket.jira_url) {
        window.open(props.ticket.jira_url, '_blank');
      }
    };

    return {
      // State
      isDragging,
      showActionsMenu,
      
      // Computed
      jiraStatus,
      
      // Methods
      getStatusColor,
      getPriorityColor,
      getPriorityBadgeColor,
      getInitials,
      formatDate,
      handleDragStart,
      handleDragEnd,
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
</style>
