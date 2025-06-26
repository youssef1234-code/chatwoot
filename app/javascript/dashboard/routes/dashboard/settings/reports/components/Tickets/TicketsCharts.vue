<script>
import { Chart as ChartJS, Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale, ArcElement, LineElement, PointElement } from 'chart.js';
import { Bar as BarChart, Doughnut as DoughnutChart, Line as LineChart } from 'vue-chartjs';

ChartJS.register(Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale, ArcElement, LineElement, PointElement);

export default {
  components: {
    BarChart,
    DoughnutChart,
    LineChart,
  },
  props: {
    ticketsData: {
      type: Array,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    statusChartData() {
      if (!this.ticketsData.length) return { labels: [], datasets: [] };
      
      const statusCounts = this.ticketsData.reduce((acc, ticket) => {
        acc[ticket.status] = (acc[ticket.status] || 0) + 1;
        return acc;
      }, {});

      return {
        labels: Object.keys(statusCounts).map(status => 
          this.$t(`TICKETS_REPORTS.STATUS.${status.toUpperCase()}`)
        ),
        datasets: [{
          data: Object.values(statusCounts),
          backgroundColor: [
            '#3B82F6', // blue
            '#F59E0B', // amber
            '#10B981', // emerald
            '#EF4444', // red
          ],
          borderWidth: 2,
          borderColor: '#fff',
        }]
      };
    },
    resolutionTrendData() {
      if (!this.ticketsData.length) return { labels: [], datasets: [] };
      
      // Group tickets by date and calculate average resolution time
      const ticketsByDate = this.ticketsData
        .filter(t => t.duration_to_resolve && t.resolved_at)
        .reduce((acc, ticket) => {
          const date = new Date(ticket.resolved_at).toDateString();
          if (!acc[date]) {
            acc[date] = { total: 0, count: 0 };
          }
          acc[date].total += ticket.duration_to_resolve;
          acc[date].count += 1;
          return acc;
        }, {});

      const sortedDates = Object.keys(ticketsByDate).sort((a, b) => new Date(a) - new Date(b));
      
      return {
        labels: sortedDates.map(date => new Date(date).toLocaleDateString()),
        datasets: [{
          label: this.$t('TICKETS_REPORTS.CHARTS.AVG_RESOLUTION_TIME'),
          data: sortedDates.map(date => Math.round(ticketsByDate[date].total / ticketsByDate[date].count / 3600)), // Convert to hours
          borderColor: '#3B82F6',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          tension: 0.4,
          fill: true,
        }]
      };
    },
    escalationByPriorityData() {
      if (!this.ticketsData.length) return { labels: [], datasets: [] };
      
      const priorityData = this.ticketsData.reduce((acc, ticket) => {
        if (!acc[ticket.priority]) {
          acc[ticket.priority] = { total: 0, escalated: 0 };
        }
        acc[ticket.priority].total += 1;
        if (ticket.escalated_to_jira) {
          acc[ticket.priority].escalated += 1;
        }
        return acc;
      }, {});

      const priorities = Object.keys(priorityData);
      
      return {
        labels: priorities.map(p => this.$t(`TICKETS_REPORTS.PRIORITY.${p.toUpperCase()}`)),
        datasets: [{
          label: this.$t('TICKETS_REPORTS.CHARTS.ESCALATION_RATE'),
          data: priorities.map(p => Math.round((priorityData[p].escalated / priorityData[p].total) * 100)),
          backgroundColor: '#F59E0B',
          borderColor: '#D97706',
          borderWidth: 1,
        }]
      };
    },
    chartOptions() {
      return {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
          },
        },
      };
    },
    lineChartOptions() {
      return {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: this.$t('TICKETS_REPORTS.CHARTS.HOURS'),
            },
          },
        },
      };
    },
    barChartOptions() {
      return {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
          },
        },
        scales: {
          y: {
            beginAtZero: true,
          },
        },
      };
    },
  },
};
</script>

<template>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Tickets by Status Chart -->
    <div class="p-6 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2">
      <h3 class="text-lg font-medium text-n-slate-12 mb-4">
        {{ $t('TICKETS_REPORTS.CHARTS.TICKETS_BY_STATUS') }}
      </h3>
      <div class="h-80">
        <div v-if="isLoading" class="flex items-center justify-center h-full">
          <div class="w-8 h-8 border-2 border-woot-500 border-t-transparent rounded-full animate-spin" />
        </div>
        <DoughnutChart
          v-else-if="statusChartData.datasets.length"
          :data="statusChartData"
          :options="chartOptions"
        />
        <div v-else class="flex items-center justify-center h-full text-n-slate-10">
          {{ $t('TICKETS_REPORTS.NO_DATA') }}
        </div>
      </div>
    </div>

    <!-- Resolution Time Trend -->
    <div class="p-6 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2">
      <h3 class="text-lg font-medium text-n-slate-12 mb-4">
        {{ $t('TICKETS_REPORTS.CHARTS.RESOLUTION_TIME_TREND') }}
      </h3>
      <div class="h-80">
        <div v-if="isLoading" class="flex items-center justify-center h-full">
          <div class="w-8 h-8 border-2 border-woot-500 border-t-transparent rounded-full animate-spin" />
        </div>
        <LineChart
          v-else-if="resolutionTrendData.datasets.length"
          :data="resolutionTrendData"
          :options="lineChartOptions"
        />
        <div v-else class="flex items-center justify-center h-full text-n-slate-10">
          {{ $t('TICKETS_REPORTS.NO_DATA') }}
        </div>
      </div>
    </div>

    <!-- Escalation Rate by Priority -->
    <div class="p-6 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 lg:col-span-2">
      <h3 class="text-lg font-medium text-n-slate-12 mb-4">
        {{ $t('TICKETS_REPORTS.CHARTS.ESCALATION_BY_PRIORITY') }}
      </h3>
      <div class="h-80">
        <div v-if="isLoading" class="flex items-center justify-center h-full">
          <div class="w-8 h-8 border-2 border-woot-500 border-t-transparent rounded-full animate-spin" />
        </div>
        <BarChart
          v-else-if="escalationByPriorityData.datasets.length"
          :data="escalationByPriorityData"
          :options="barChartOptions"
        />
        <div v-else class="flex items-center justify-center h-full text-n-slate-10">
          {{ $t('TICKETS_REPORTS.NO_DATA') }}
        </div>
      </div>
    </div>
  </div>
</template>
