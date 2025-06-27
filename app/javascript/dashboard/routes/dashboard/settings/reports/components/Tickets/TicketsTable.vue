
<script>
import { messageStamp } from 'shared/helpers/timeHelper';

export default {
  props: {
    tickets: {
      type: Array,
      default: () => [],
    },
    pageInfo: {
      type: Object,
      default: () => ({}),
    },
    onPageChange: {
      type: Function,
      default: () => {},
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const formatDate = (timestamp) => {
      if (!timestamp) return '-';
      // Backend sends Unix timestamps (seconds), convert to milliseconds
      const date = new Date(timestamp * 1000);
      return messageStamp(Math.floor(date.getTime() / 1000), 'MMM dd, yyyy h:mm a');
    };
    return { formatDate };
  },
  methods: {
    getStatusBadgeClass(status) {
      const classes = {
        open: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300',
        in_progress: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
        escalated: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
        resolved: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
        closed: 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300',
      };
      return classes[status] || 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
    },
    getPriorityBadgeClass(priority) {
      const classes = {
        low: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
        medium: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
        high: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300',
        urgent: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
      };
      return classes[priority] || 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
    },
    getJiraStatusBadgeClass(ticket) {
      if (!ticket.escalated_to_jira) {
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
      }
      
      // Check if ticket is resolved/closed (done)
      if (ticket.status === 'resolved' || ticket.status === 'closed') {
        return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300';
      }
      
      // Check if JIRA issue is in progress
      if (ticket.jira_in_progress) {
        return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300';
      }
      
      // Otherwise it's escalated but not yet in progress
      return 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300';
    },
    getJiraStatusText(ticket) {
      if (!ticket.escalated_to_jira) {
        return this.$t('TICKETS_REPORTS.JIRA_STATUS.NOT_ESCALATED');
      }
      
      // Check if ticket is resolved/closed (done)
      if (ticket.status === 'resolved' || ticket.status === 'closed') {
        return this.$t('TICKETS_REPORTS.JIRA_STATUS.DONE');
      }
      
      // Check if JIRA issue is in progress
      if (ticket.jira_in_progress) {
        return this.$t('TICKETS_REPORTS.JIRA_STATUS.IN_PROGRESS');
      }
      
      // Otherwise it's escalated but not yet in progress
      return this.$t('TICKETS_REPORTS.JIRA_STATUS.ESCALATED');
    },
    formatDuration(seconds) {
      if (!seconds) return '-';
      
      const hours = Math.floor(seconds / 3600);
      const minutes = Math.floor((seconds % 3600) / 60);
      
      if (hours > 24) {
        const days = Math.floor(hours / 24);
        const remainingHours = hours % 24;
        return `${days}d ${remainingHours}h`;
      }
      
      return `${hours}h ${minutes}m`;
    },
  },
};
</script>

<template>
  <div class="shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2">
    <div class="px-6 py-4 border-b border-n-weak">
      <h3 class="text-lg font-medium text-n-slate-12">
        {{ $t('TICKETS_REPORTS.TABLE.TITLE') }}
      </h3>
    </div>
    
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-n-weak">
        <thead class="bg-n-solid-3">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              {{ $t('TICKETS_REPORTS.TABLE.TICKET_ID') }}
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              {{ $t('TICKETS_REPORTS.TABLE.TITLE') }}
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              {{ $t('TICKETS_REPORTS.TABLE.STATUS') }}
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              {{ $t('TICKETS_REPORTS.TABLE.PRIORITY') }}
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              {{ $t('TICKETS_REPORTS.TABLE.AGENT') }}
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              {{ $t('TICKETS_REPORTS.TABLE.JIRA_STATUS') }}
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              {{ $t('TICKETS_REPORTS.TABLE.RESOLUTION_TIME') }}
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-n-slate-11 uppercase tracking-wider">
              {{ $t('TICKETS_REPORTS.TABLE.CREATED_AT') }}
            </th>
          </tr>
        </thead>
        <tbody class="bg-n-solid-2 divide-y divide-n-weak">
          <!-- Loading State -->
          <template v-if="isLoading">
            <tr v-for="n in 5" :key="n">
              <td v-for="col in 8" :key="col" class="px-6 py-4 whitespace-nowrap">
                <div class="w-20 h-4 bg-n-slate-3 rounded animate-pulse" />
              </td>
            </tr>
          </template>
          
          <!-- Data Rows -->
          <tr 
            v-else
            v-for="ticket in tickets" 
            :key="ticket.id" 
            class="hover:bg-n-solid-3 transition-colors"
          >
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-n-slate-12">
              #{{ ticket.id }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-n-slate-12">
              <div class="max-w-xs truncate" :title="ticket.title">
                {{ ticket.title }}
              </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span 
                :class="getStatusBadgeClass(ticket.status)" 
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
              >
                {{ ticket.status ? $t(`TICKETS_REPORTS.STATUS.${ticket.status.toUpperCase()}`) : '-' }}
              </span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span 
                :class="getPriorityBadgeClass(ticket.priority)" 
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
              >
                {{ ticket.priority ? $t(`TICKETS_REPORTS.PRIORITY.${ticket.priority.toUpperCase()}`) : '-' }}
              </span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-n-slate-12">
              {{ ticket.assigned_agent?.name || $t('TICKETS_REPORTS.UNASSIGNED') }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <div class="flex flex-col space-y-1">
                <span 
                  :class="getJiraStatusBadgeClass(ticket)" 
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                >
                  {{ getJiraStatusText(ticket) }}
                </span>
                <div v-if="ticket.jira_issue_key" class="text-xs">
                  <a 
                    v-if="ticket.jira_url"
                    :href="ticket.jira_url" 
                    target="_blank" 
                    rel="noopener noreferrer"
                    class="text-woot-500 hover:text-woot-600 underline"
                  >
                    {{ ticket.jira_issue_key }}
                  </a>
                  <span v-else class="text-n-slate-10">
                    {{ ticket.jira_issue_key }}
                  </span>
                </div>
              </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-n-slate-12">
              {{ formatDuration(ticket.duration_to_resolve) }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-n-slate-12">
              {{ formatDate(ticket.created_at) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    
    <!-- Empty State -->
    <div v-if="!isLoading && !tickets.length" class="text-center py-12">
      <div class="text-n-slate-10">
        <fluent-icon icon="clipboard-list" size="48" class="mx-auto mb-4" />
        <p class="text-lg font-medium mb-2">{{ $t('TICKETS_REPORTS.NO_TICKETS') }}</p>
        <p class="text-sm">{{ $t('TICKETS_REPORTS.NO_TICKETS_DESCRIPTION') }}</p>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="pageInfo && pageInfo.total_pages > 1" class="px-6 py-4 border-t border-n-weak">
      <div class="flex items-center justify-between">
        <div class="text-sm text-n-slate-11">
          {{ $t('REPORT.PAGINATION.RESULTS', {
            firstIndex: ((pageInfo.current_page - 1) * pageInfo.per_page) + 1,
            lastIndex: Math.min(pageInfo.current_page * pageInfo.per_page, pageInfo.total_count),
            totalCount: pageInfo.total_count
          }) }}
        </div>
        <div class="flex space-x-2">
          <button
            :disabled="pageInfo.current_page <= 1"
            class="px-3 py-1 text-sm border border-n-weak rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-n-solid-3"
            @click="onPageChange(pageInfo.current_page - 1)"
          >
            {{ $t('FORMS.BUTTONS.PREVIOUS') }}
          </button>
          <button
            :disabled="pageInfo.current_page >= pageInfo.total_pages"
            class="px-3 py-1 text-sm border border-n-weak rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-n-solid-3"
            @click="onPageChange(pageInfo.current_page + 1)"
          >
            {{ $t('FORMS.BUTTONS.NEXT') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
