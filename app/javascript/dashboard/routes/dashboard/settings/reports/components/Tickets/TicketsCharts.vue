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
    summaryData: {
      type: Object,
      default: () => ({}),
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    statusChartData() {
      if (!this.summaryData.status_distribution || Object.keys(this.summaryData.status_distribution).length === 0) {
        return { labels: [], datasets: [] };
      }
      
      const statusCounts = this.summaryData.status_distribution;

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
      if (!this.summaryData.resolution_time_trend || Object.keys(this.summaryData.resolution_time_trend).length === 0) {
        return { labels: [], datasets: [] };
      }
      
      const trendData = this.summaryData.resolution_time_trend;
      const sortedDates = Object.keys(trendData).sort((a, b) => new Date(a) - new Date(b));
      
      return {
        labels: sortedDates.map(date => new Date(date).toLocaleDateString()),
        datasets: [{
          label: this.$t('TICKETS_REPORTS.CHARTS.AVG_RESOLUTION_TIME'),
          data: sortedDates.map(date => Math.round(trendData[date] / 3600)), // Convert to hours
          borderColor: '#3B82F6',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          tension: 0.4,
          fill: true,
        }]
      };
    },
    escalationByPriorityData() {
      if (!this.summaryData.escalation_by_priority || Object.keys(this.summaryData.escalation_by_priority).length === 0) {
        return { labels: [], datasets: [] };
      }
      
      const priorityData = this.summaryData.escalation_by_priority;
      const priorities = Object.keys(priorityData);
      
      return {
        labels: priorities.map(p => this.$t(`TICKETS_REPORTS.PRIORITY.${p.toUpperCase()}`)),
        datasets: [{
          label: this.$t('TICKETS_REPORTS.CHARTS.ESCALATION_RATE'),
          data: priorities.map(p => priorityData[p].escalation_rate),
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
