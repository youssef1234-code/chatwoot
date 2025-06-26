<script setup>
import TicketsMetricCard from './TicketsMetricCard.vue';

defineProps({
  totalTickets: {
    type: Number,
    required: true,
  },
  avgResolutionTime: {
    type: Number,
    required: true,
  },
  escalationPercentage: {
    type: Number,
    required: true,
  },
  resolvedAfterEscalation: {
    type: Number,
    required: true,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const formatDuration = (seconds) => {
  if (!seconds) return '0h';
  
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  
  if (hours > 24) {
    const days = Math.floor(hours / 24);
    const remainingHours = hours % 24;
    return `${days}d ${remainingHours}h`;
  }
  
  return `${hours}h ${minutes}m`;
};
</script>

<template>
  <div
    class="flex sm:flex-row flex-col w-full gap-4 sm:gap-14 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-5"
  >
    <TicketsMetricCard
      :label="$t('TICKETS_REPORTS.METRICS.TOTAL_TICKETS')"
      :value="totalTickets"
      :tool-tip="$t('TICKETS_REPORTS.METRICS.TOTAL_TICKETS_TOOLTIP')"
      :is-loading="isLoading"
    />

    <div class="w-full sm:w-px bg-n-strong" />
    
    <TicketsMetricCard
      :label="$t('TICKETS_REPORTS.METRICS.AVG_RESOLUTION_TIME')"
      :value="formatDuration(avgResolutionTime)"
      :tool-tip="$t('TICKETS_REPORTS.METRICS.AVG_RESOLUTION_TIME_TOOLTIP')"
      :is-loading="isLoading"
    />
    
    <div class="w-full sm:w-px bg-n-strong" />
    
    <TicketsMetricCard
      :label="$t('TICKETS_REPORTS.METRICS.ESCALATION_PERCENTAGE')"
      :value="escalationPercentage + '%'"
      :tool-tip="$t('TICKETS_REPORTS.METRICS.ESCALATION_PERCENTAGE_TOOLTIP')"
      :is-loading="isLoading"
    />
    
    <div class="w-full sm:w-px bg-n-strong" />
    
    <TicketsMetricCard
      :label="$t('TICKETS_REPORTS.METRICS.RESOLVED_AFTER_ESCALATION')"
      :value="resolvedAfterEscalation + '%'"
      :tool-tip="$t('TICKETS_REPORTS.METRICS.RESOLVED_AFTER_ESCALATION_TOOLTIP')"
      :is-loading="isLoading"
    />
  </div>
</template>
