<script>
import { mapGetters } from 'vuex';
import NpsMetricCard from './ReportMetricCard.vue';
import { NPS_RATINGS } from 'shared/constants/messages';
import BarChart from 'shared/components/charts/BarChart.vue';

export default {
  components: { BarChart, NpsMetricCard },
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      npsRatings: NPS_RATINGS,
    };
  },
  computed: {
    ...mapGetters({
      metrics: 'nps/getMetrics',
      ratingPercentage: 'nps/getRatingPercentage',
      netPromoterScore: 'nps/getNetPromoterScore',
      responseRate: 'nps/getResponseRate',
      promoterPercentage: 'nps/getPromoterPercentage',
      passivePercentage: 'nps/getPassivePercentage',
      detractorPercentage: 'nps/getDetractorPercentage',
    }),
    ratingFilterEnabled() {
      return Boolean(this.filters.rating);
    },
    chartData() {
      const ratings = [...Array(11).keys()]; // 0-10
      return {
        labels: ['Rating'],
        datasets: ratings.map(rating => ({
          label: rating.toString(),
          data: [this.ratingPercentage[rating]],
          backgroundColor: this.getRatingColor(rating),
        })),
      };
    },
    responseCount() {
      return this.metrics.totalResponseCount
        ? this.metrics.totalResponseCount.toLocaleString()
        : '--';
    },
    chartOptions() {
      return {
        indexAxis: 'y',
        responsive: true,
        plugins: {
          legend: {
            display: false,
          },
          title: {
            display: false,
          },
          tooltip: {
            enabled: false,
          },
        },
        scales: {
          x: {
            display: false,
            stacked: true,
          },
          y: {
            display: false,
            stacked: true,
          },
        },
      };
    },
  },
  methods: {
    formatToPercent(value) {
      return value ? `${value}%` : '--';
    },
    getRatingColor(rating) {
      if (rating >= 0 && rating <= 6) return '#ef4444'; // red for detractors
      if (rating >= 7 && rating <= 8) return '#f59e0b'; // yellow for passives
      return '#10b981'; // green for promoters
    },
  },
};
</script>

<template>
  <div
    class="flex-col lg:flex-row flex flex-wrap mx-0 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-8 gap-4"
  >
    <NpsMetricCard
      :label="$t('NPS_REPORTS.METRIC.TOTAL_RESPONSES.LABEL')"
      :info-text="$t('NPS_REPORTS.METRIC.TOTAL_RESPONSES.TOOLTIP')"
      :value="responseCount"
      class="xs:w-full sm:max-w-[50%] lg:w-1/6 lg:max-w-[16%]"
    />
    <NpsMetricCard
      :disabled="ratingFilterEnabled"
      :label="$t('NPS_REPORTS.METRIC.NET_PROMOTER_SCORE.LABEL')"
      :info-text="$t('NPS_REPORTS.METRIC.NET_PROMOTER_SCORE.TOOLTIP')"
      :value="ratingFilterEnabled ? '--' : formatToPercent(netPromoterScore)"
      class="xs:w-full sm:max-w-[50%] lg:w-1/6 lg:max-w-[16%]"
    />
    <NpsMetricCard
      :label="$t('NPS_REPORTS.METRIC.RESPONSE_RATE.LABEL')"
      :info-text="$t('NPS_REPORTS.METRIC.RESPONSE_RATE.TOOLTIP')"
      :value="formatToPercent(responseRate)"
      class="xs:w-full sm:max-w-[50%] lg:w-1/6 lg:max-w-[16%]"
    />

    <div
      v-if="metrics.totalResponseCount && !ratingFilterEnabled"
      ref="npsBarChart"
      class="w-full md:w-1/2 md:max-w-[50%] flex-1 rtl:[direction:initial]"
    >
      <h3
        class="flex items-center m-0 text-xs font-medium md:text-sm text-n-slate-12"
      >
        <div class="flex flex-row gap-6">
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 rounded" style="background-color: #ef4444;"></div>
            <span>{{ $t('NPS_REPORTS.CHART.DETRACTORS') }}: {{ formatToPercent(detractorPercentage) }}</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 rounded" style="background-color: #f59e0b;"></div>
            <span>{{ $t('NPS_REPORTS.CHART.PASSIVES') }}: {{ formatToPercent(passivePercentage) }}</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 rounded" style="background-color: #10b981;"></div>
            <span>{{ $t('NPS_REPORTS.CHART.PROMOTERS') }}: {{ formatToPercent(promoterPercentage) }}</span>
          </div>
        </div>
      </h3>
      <div class="mt-2 h-6">
        <BarChart :collection="chartData" :chart-options="chartOptions" />
      </div>
    </div>
  </div>
</template>
