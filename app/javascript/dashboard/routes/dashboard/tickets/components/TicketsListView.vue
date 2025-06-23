<template>
  <div class="p-6">
    <!-- Loading State -->
    <div v-if="isLoading" class="space-y-4">
      <div
        v-for="n in 5"
        :key="n"
        class="animate-pulse bg-n-alpha-2 rounded-lg p-4 h-24"
      />
    </div>

    <!-- Empty State -->
    <div v-else-if="tickets.length === 0" class="text-center py-12">
      <Icon icon="i-lucide-ticket" class="w-16 h-16 text-n-slate-7 mx-auto mb-4" />
      <h3 class="text-lg font-medium text-n-slate-12 mb-2">
        {{ $t('TICKETS.EMPTY_STATE.TITLE') }}
      </h3>
      <p class="text-sm text-n-slate-9">
        {{ $t('TICKETS.EMPTY_STATE.DESCRIPTION') }}
      </p>
    </div>

    <!-- Tickets List -->
    <div v-else class="space-y-4">
      <div
        v-for="ticket in tickets"
        :key="ticket.id"
        class="bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg p-4 hover:border-blue-200 hover:shadow-sm transition-all cursor-pointer"
        @click="$emit('ticket-click', ticket)"
      >
        <div class="flex items-start justify-between">
          <!-- Left Content -->
          <div class="flex-1">
            <div class="flex items-center gap-3 mb-2">
              <!-- Status Badge -->
              <span
                :class="getStatusBadgeClass(ticket.status)"
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
              >
                {{ getStatusLabel(ticket.status) }}
              </span>

              <!-- Priority Badge -->
              <span
                :class="getPriorityBadgeClass(ticket.priority)"
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
              >
                {{ getPriorityLabel(ticket.priority) }}
              </span>

              <!-- JIRA Badge -->
              <span
                v-if="ticket.jira_issue_key"
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
              >
                <Icon icon="i-lucide-external-link" class="w-3 h-3 mr-1" />
                {{ ticket.jira_issue_key }}
              </span>

              <!-- Ticket ID -->
              <span class="text-xs text-n-slate-9">
                #{{ ticket.id }}
              </span>
            </div>

            <!-- Title -->
            <h3 class="text-lg font-medium text-n-slate-12 mb-2 line-clamp-1">
              {{ ticket.title || $t('TICKETS.UNTITLED') }}
            </h3>

            <!-- Description -->
            <p
              v-if="ticket.description"
              class="text-sm text-n-slate-9 mb-3 line-clamp-2"
            >
              {{ ticket.description }}
            </p>

            <!-- Meta Information -->
            <div class="flex items-center gap-4 text-xs text-n-slate-9">
              <span class="flex items-center gap-1">
                <Icon icon="i-lucide-user" class="w-3 h-3" />
                {{ ticket.created_by?.name || $t('TICKETS.UNASSIGNED') }}
              </span>
              <span class="flex items-center gap-1">
                <Icon icon="i-lucide-calendar" class="w-3 h-3" />
                {{ formatDate(ticket.created_at) }}
              </span>
              <span
                v-if="ticket.assigned_agent"
                class="flex items-center gap-1"
              >
                <Icon icon="i-lucide-user-check" class="w-3 h-3" />
                {{ ticket.assigned_agent.name }}
              </span>
              <span
                v-if="ticket.conversation"
                class="flex items-center gap-1"
              >
                <Icon icon="i-lucide-message-circle" class="w-3 h-3" />
                {{ $t('TICKETS.DETAIL.CONVERSATION_ID', { id: ticket.conversation.display_id }) }}
              </span>
            </div>
          </div>

          <!-- Right Actions -->
          <div class="flex items-center gap-2 ml-4">
            <!-- AI Enhancement Button -->
            <NextButton
              v-if="canEnhanceWithAi(ticket)"
              variant="ghost"
              color="blue"
              size="sm"
              @click.stop="$emit('enhance-with-ai', ticket)"
            >
              <Icon icon="i-lucide-sparkles" class="w-4 h-4" />
            </NextButton>

            <!-- Quick Actions -->
            <div class="flex items-center gap-1">
              <NextButton
                v-if="ticket.status !== 'resolved' && ticket.status !== 'closed'"
                variant="ghost"
                size="sm"
                color="teal"
                @click.stop="resolveTicket(ticket)"
              >
                <Icon icon="i-lucide-check" class="w-4 h-4" />
              </NextButton>

              <NextButton
                v-if="canEscalateToJira(ticket)"
                variant="ghost"
                size="sm"
                color="amber"
                @click.stop="escalateToJira(ticket)"
              >
                <Icon icon="i-lucide-external-link" class="w-4 h-4" />
              </NextButton>

              <NextButton
                variant="ghost"
                color="slate"
                size="sm"
                @click.stop="openConversation(ticket)"
              >
                <Icon icon="i-lucide-message-circle" class="w-4 h-4" />
              </NextButton>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { format } from 'date-fns';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

import { useAlert } from 'dashboard/composables';

export default {
  name: 'TicketsListView',
  components: {
    NextButton,
    Icon,
  },
  props: {
    tickets: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
    currentUser: {
      type: Object,
      required: true,
    },
  },
  emits: ['ticket-click', 'ticket-updated', 'enhance-with-ai'],
  setup(props, { emit }) {
    const store = useStore();
    const { t } = useI18n();
    const router = useRouter();

    // Methods
    const getStatusBadgeClass = (status) => {
      const classes = {
        open: 'bg-blue-100 text-blue-800',
        in_progress: 'bg-yellow-100 text-yellow-800',
        escalated: 'bg-orange-100 text-orange-800',
        resolved: 'bg-green-100 text-green-800',
        closed: 'bg-gray-100 text-gray-800',
      };
      return classes[status] || 'bg-gray-100 text-gray-800';
    };

    const getPriorityBadgeClass = (priority) => {
      const classes = {
        low: 'bg-gray-100 text-gray-800',
        medium: 'bg-blue-100 text-blue-800',
        high: 'bg-orange-100 text-orange-800',
        urgent: 'bg-red-100 text-red-800',
      };
      return classes[priority] || 'bg-gray-100 text-gray-800';
    };

    const getStatusLabel = (status) => {
      const labels = {
        open: t('TICKETS.STATUS.OPEN'),
        in_progress: t('TICKETS.STATUS.IN_PROGRESS'),
        escalated: t('TICKETS.STATUS.ESCALATED'),
        resolved: t('TICKETS.STATUS.RESOLVED'),
        closed: t('TICKETS.STATUS.CLOSED'),
      };
      return labels[status] || status;
    };

    const getPriorityLabel = (priority) => {
      const labels = {
        low: t('TICKETS.PRIORITY.LOW'),
        medium: t('TICKETS.PRIORITY.MEDIUM'),
        high: t('TICKETS.PRIORITY.HIGH'),
        urgent: t('TICKETS.PRIORITY.URGENT'),
      };
      return labels[priority] || priority;
    };

    const formatDate = (dateString) => {
      if (!dateString) return '';
      try {
        return format(new Date(dateString), 'MMM dd, yyyy');
      } catch (error) {
        return dateString;
      }
    };

    const canEnhanceWithAi = (ticket) => {
      return ticket.status !== 'resolved' && ticket.status !== 'closed';
    };

    const canEscalateToJira = (ticket) => {
      return !ticket.jira_issue_key && 
             (ticket.status === 'open' || ticket.status === 'in_progress');
    };

    const resolveTicket = async (ticket) => {
      try {
        await store.dispatch('tickets/resolve', ticket.id);
        emit('ticket-updated');
        useAlert(t('TICKETS.RESOLVE_SUCCESS'));
      } catch (error) {
        console.error('Failed to resolve ticket:', error);
        useAlert(t('TICKETS.RESOLVE_ERROR'));
      }
    };

    const escalateToJira = async (ticket) => {
      const jiraIssueKey = prompt(t('TICKETS.DETAIL.ENTER_JIRA_KEY'));
      if (!jiraIssueKey) return;

      try {
        await store.dispatch('tickets/escalateToJira', {
          ticketId: ticket.id,
          jiraIssueKey,
        });
        emit('ticket-updated');
        useAlert(t('TICKETS.ESCALATE_SUCCESS'));
      } catch (error) {
        console.error('Failed to escalate ticket to JIRA:', error);
        useAlert(t('TICKETS.ESCALATE_ERROR'));
      }
    };

    const openConversation = (ticket) => {
      if (ticket.conversation?.id) {
        const accountId = router.currentRoute.value.params.accountId;
        const conversationUrl = `/app/accounts/${accountId}/conversations/${ticket.conversation.id}`;
        window.open(conversationUrl, '_blank');
      }
    };

    return {
      // Methods
      getStatusBadgeClass,
      getPriorityBadgeClass,
      getStatusLabel,
      getPriorityLabel,
      formatDate,
      canEnhanceWithAi,
      canEscalateToJira,
      resolveTicket,
      escalateToJira,
      openConversation,
    };
  },
};
</script>

<style scoped>
.line-clamp-1 {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
