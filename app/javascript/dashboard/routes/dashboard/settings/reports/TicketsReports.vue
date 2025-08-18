<script>
import { mapGetters } from 'vuex';
import V4Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import ReportHeader from './components/ReportHeader.vue';
import TicketsMetrics from './components/Tickets/TicketsMetrics.vue';
import TicketsTable from './components/Tickets/TicketsTable.vue';
import TicketsReportFilters from './components/Tickets/TicketsReportFilters.vue';
import TicketsCharts from './components/Tickets/TicketsCharts.vue';
import { generateFileName } from 'dashboard/helper/downloadHelper';

export default {
  name: 'TicketsReports',
  components: {
    V4Button,
    ReportHeader,
    TicketsMetrics,
    TicketsTable,
    TicketsReportFilters,
    TicketsCharts,
  },
  data() {
    // Set default date range to last 30 days
    const now = new Date();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(now.getDate() - 30);
    
    return {
      pageNumber: 1,
      activeFilter: {
        from: Math.floor(thirtyDaysAgo.getTime() / 1000), // Unix timestamp
        to: Math.floor(now.getTime() / 1000), // Unix timestamp
        status: null,
        priority: null,
        category: null,
        assigned_agent_id: null,
        jira_status: null,
        linked_with_jira: null,
        // Feature request filters (default to regular tickets only)
        feature_requests_only: null,
        include_feature_requests: null,
      },
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      currentUser: 'getCurrentUser',
      currentAccount: 'getCurrentAccount',
      tickets: 'ticketsReports/getAll',
      metrics: 'ticketsReports/getMetrics',
      summary: 'ticketsReports/getSummary',
      uiFlags: 'ticketsReports/getUIFlags',
      meta: 'ticketsReports/getMeta',
    }),
    ticketCategories() {
      return this.currentAccount?.settings?.ticket_categories || [];
    },
    formattedMetrics() {
      return {
        totalTickets: this.metrics.totalTickets,
        avgResolutionTime: this.formatDuration(this.metrics.avgResolutionTime),
        escalationPercentage: this.metrics.escalationPercentage,
        resolvedAfterEscalation: this.metrics.resolvedAfterEscalation,
      };
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.fetchTicketsReports();
    this.fetchTicketsMetrics();
    this.fetchTicketsSummary();
  },
  methods: {
    fetchTicketsReports({ pageNumber } = {}) {
      this.pageNumber = pageNumber || this.pageNumber;
      const params = {
        ...this.activeFilter,
        page: this.pageNumber,
      };
      this.$store.dispatch('ticketsReports/get', params);
    },
    
    fetchTicketsMetrics() {
      const params = {
        ...this.activeFilter,
      };
      this.$store.dispatch('ticketsReports/getMetrics', params);
    },

    fetchTicketsSummary() {
      const params = {
        ...this.activeFilter,
      };
      this.$store.dispatch('ticketsReports/getSummary', params);
    },
    
    onPageChange(pageNumber) {
      this.fetchTicketsReports({ pageNumber });
    },
    
    onFilterChange(params) {
      this.activeFilter = params;
      this.pageNumber = 1; // Reset to first page when filters change
      this.fetchTicketsReports();
      this.fetchTicketsMetrics();
      this.fetchTicketsSummary();
    },
    
    async downloadReports() {
      try {
        const fileName = generateFileName({ 
          type: 'tickets-report', 
          to: this.activeFilter.to,
          businessHours: this.activeFilter.businessHours 
        });
        const params = {
          ...this.activeFilter,
          fileName,
        };
        await this.$store.dispatch('ticketsReports/download', params);
      } catch (error) {
        console.log(error);
        useAlert(this.$t('TICKETS_REPORTS.DOWNLOAD_FAILED'));
      }
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
  <ReportHeader 
    :header-title="$t('TICKETS_REPORTS.HEADER')"
    :header-description="$t('TICKETS_REPORTS.DESCRIPTION')"
  >
    <V4Button
      :label="$t('TICKETS_REPORTS.DOWNLOAD_TICKETS_REPORTS')"
      icon="i-ph-download-simple"
      size="sm"
      @click="downloadReports"
    />
  </ReportHeader>
  
  <div class="flex flex-col flex-1 gap-6">
    <TicketsReportFilters 
      :ticket-categories="ticketCategories"
      @filter-change="onFilterChange" 
    />
    
    <TicketsMetrics
      :total-tickets="metrics.totalTickets"
      :avg-resolution-time="metrics.avgResolutionTime"
      :escalation-percentage="metrics.escalationPercentage"
      :resolved-after-escalation="metrics.resolvedAfterEscalation"
      :is-loading="uiFlags.isFetchingMetrics"
    />
    
    <TicketsCharts
      :summary-data="summary"
      :is-loading="uiFlags.isFetchingSummary"
    />
    
    <TicketsTable
      :tickets="tickets"
      :page-info="meta"
      :on-page-change="onPageChange"
      :is-loading="uiFlags.isFetching"
    />
  </div>
</template>
