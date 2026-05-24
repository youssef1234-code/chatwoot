<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import Spinner from 'shared/components/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import JiraAPI from 'dashboard/api/integrations/jira';

const POLL_INTERVAL = 5 * 60 * 1000; // 5 minutes

const props = defineProps({
  contact: {
    type: Object,
    required: true,
  },
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const isLoading = ref(false);
const isRefreshing = ref(false);
const onboardingData = ref(null);
const statusConfig = ref({ done_statuses: [], in_progress_statuses: [] });
const error = ref(null);
const expandedSession = ref(null);
const lastUpdated = ref(null);
let pollTimer = null;

const hasOrg = computed(() => {
  const ca = props.contact?.custom_attributes || {};
  const aa = props.contact?.additional_attributes || {};
  return !!(
    ca.organization || ca.company || ca.org ||
    ca.company_name || ca.organisation || ca.slug ||
    aa.company_name || aa.organization
  );
});

// Computed org value — used to detect org field changes on the contact
const currentOrg = computed(() => {
  const ca = props.contact?.custom_attributes || {};
  const aa = props.contact?.additional_attributes || {};
  return ca.organization || ca.company || ca.org ||
    ca.company_name || ca.organisation || ca.slug ||
    aa.company_name || aa.organization || null;
});

const progressStage = computed(() => onboardingData.value?.progress?.stage || '');
const overallPercent = computed(() => onboardingData.value?.progress?.overall_percent || 0);
const sessions = computed(() => onboardingData.value?.sessions || []);
const onboarding = computed(() => onboardingData.value?.onboarding || {});

const isDone = (status) => {
  const s = (status || '').toLowerCase().trim();
  return statusConfig.value.done_statuses.some(d => d.toLowerCase().trim() === s);
};

// Return the configured hex color for a status, with a sensible fallback
const statusColor = (status) => {
  if (!status) return '#6b7280';
  const mapping = statusConfig.value.status_color_mapping || {};
  // exact match first
  if (mapping[status]) return mapping[status];
  // case-insensitive fallback
  const lower = status.toLowerCase();
  const key = Object.keys(mapping).find(k => k.toLowerCase() === lower);
  return key ? mapping[key] : '#6b7280';
};

// Derive a readable text color (white for dark bg, dark for light bg)
const contrastColor = (hex) => {
  const c = hex.replace('#', '');
  const r = parseInt(c.substr(0, 2), 16);
  const g = parseInt(c.substr(2, 2), 16);
  const b = parseInt(c.substr(4, 2), 16);
  return (r * 299 + g * 587 + b * 114) / 1000 > 150 ? '#1f2937' : '#ffffff';
};

// Badge style: colored border + text, transparent bg
const badgeStyle = (status) => {
  const color = statusColor(status);
  return { color, borderColor: color, background: `${color}1a` };
};

// Dot style: filled with status color
const dotStyle = (session) => {
  const color = statusColor(session.status);
  return { background: color, color: contrastColor(color), borderColor: color };
};

// Connector style between two adjacent session dots
const connectorStyle = (session) => {
  const color = statusColor(session.status);
  return { background: color };
};

const toggleSession = (index) => {
  expandedSession.value = expandedSession.value === index ? null : index;
};

const fetchOnboardingStatus = async ({ silent = false, force = false } = {}) => {
  if (!hasOrg.value || !props.conversationId) {
    onboardingData.value = null;
    return;
  }

  if (silent) {
    isRefreshing.value = true;
  } else {
    isLoading.value = true;
  }
  error.value = null;

  try {
    const response = await JiraAPI.getOnboardingStatus(props.conversationId, { force });
    const result = response.data?.data;
    onboardingData.value = result || null;
    if (response.data?.config) {
      statusConfig.value = response.data.config;
    }
    lastUpdated.value = new Date();
  } catch (err) {
    if (err.response?.status === 404) {
      onboardingData.value = null;
    } else {
      console.error('Failed to fetch onboarding status:', err);
      if (!silent) error.value = 'Failed to load onboarding status';
    }
  } finally {
    isLoading.value = false;
    isRefreshing.value = false;
  }
};

// Manual refresh: bypass Redis cache
const refreshStatus = () => fetchOnboardingStatus({ silent: true, force: true });

const startPolling = () => {
  stopPolling();
  pollTimer = setInterval(() => fetchOnboardingStatus({ silent: true }), POLL_INTERVAL);
};

const stopPolling = () => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
};

const timeAgo = computed(() => {
  if (!lastUpdated.value) return '';
  const seconds = Math.floor((Date.now() - lastUpdated.value.getTime()) / 1000);
  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  return `${Math.floor(minutes / 60)}h ago`;
});

const openInJira = (url) => {
  if (url) window.open(url, '_blank');
};

// Refetch when contact's org changes (set, updated, or cleared)
watch(currentOrg, (newOrg, oldOrg) => {
  if (newOrg !== oldOrg) {
    expandedSession.value = null;
    // Org changed — force fetch to bypass cache for the new org
    fetchOnboardingStatus({ force: true });
    startPolling();
  }
});
// Refetch when switching conversations
watch(() => props.conversationId, () => {
  expandedSession.value = null;
  fetchOnboardingStatus();
  startPolling();
});
onMounted(() => {
  fetchOnboardingStatus();
  startPolling();
});
onBeforeUnmount(() => stopPolling());
</script>

<template>
  <div class="onboarding-status-widget">
    <!-- Loading -->
    <div v-if="isLoading" class="flex justify-center p-6">
      <Spinner />
    </div>

    <!-- No org on contact -->
    <div v-else-if="!hasOrg" class="p-4 text-center">
      <p class="text-sm text-n-slate-11">
        No organization found on this contact.
      </p>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="p-4 text-center">
      <p class="text-sm text-red-600">{{ error }}</p>
      <NextButton size="tiny" class="mt-2" @click="fetchOnboardingStatus">
        Retry
      </NextButton>
    </div>

    <!-- Not in onboarding -->
    <div v-else-if="!onboardingData || !onboardingData.onboarding" class="p-4 text-center">
      <div class="flex flex-col items-center gap-2">
        <i class="ri-check-double-line text-2xl text-n-slate-10" />
        <p class="text-sm text-n-slate-11">Not in onboarding</p>
      </div>
    </div>

    <!-- Onboarding status -->
    <div v-else class="p-4 space-y-4">
      <!-- Header: status badge + refresh + % -->
      <div class="flex items-center justify-between gap-2">
        <span
          class="px-2.5 py-1 rounded-full text-xs font-semibold border shrink-0"
          :style="badgeStyle(progressStage)"
        >
          {{ progressStage }}
        </span>
        <div class="flex items-center gap-2 ml-auto">
          <span v-if="timeAgo" class="text-[10px] text-n-slate-9">{{ timeAgo }}</span>
          <button
            class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-10 hover:text-n-slate-12 transition-colors"
            :class="{ 'animate-spin': isRefreshing }"
            title="Refresh onboarding status"
            :disabled="isRefreshing"
            @click="refreshStatus"
          >
            <i class="ri-refresh-line text-sm" />
          </button>
          <span class="text-xs text-n-slate-10 font-medium tabular-nums">
            {{ overallPercent }}%
          </span>
        </div>
      </div>

      <!-- Overall progress bar -->
      <div class="w-full bg-n-alpha-3 rounded-full h-1.5 overflow-hidden">
        <div
          class="h-full rounded-full transition-all duration-500 ease-out"
          :style="{
            width: `${overallPercent}%`,
            background: statusColor(progressStage),
          }"
        />
      </div>

      <!-- Session steps -->
      <div class="flex items-center gap-1.5">
        <template v-for="(session, idx) in sessions" :key="session.key || idx">
          <button
            class="flex items-center justify-center w-6 h-6 rounded-full text-[11px] font-bold shrink-0 transition-all duration-150 focus:outline-none border-2"
            :class="{ 'scale-110 ring-2 ring-offset-1 ring-offset-n-bg': expandedSession === idx }"
            :style="dotStyle(session)"
            :title="`${session.title} — ${session.status}`"
            @click="toggleSession(idx)"
          >
            <i v-if="isDone(session.status)" class="ri-check-line" style="font-size:10px" />
            <span v-else class="leading-none">{{ session.number ?? (idx + 1) }}</span>
          </button>
          <!-- Connector between dots — colored by the left session's status -->
          <div
            v-if="idx < sessions.length - 1"
            class="flex-1 h-0.5 min-w-0 rounded-full transition-colors duration-300 bg-n-alpha-3"
            :style="isDone(session.status) ? connectorStyle(session) : {}"
          />
        </template>
      </div>

      <!-- Expanded session detail -->
      <div
        v-if="expandedSession !== null && sessions[expandedSession]"
        class="border border-n-weak rounded-lg p-3 space-y-3"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm font-semibold text-n-slate-12 min-w-0 truncate">
            {{ sessions[expandedSession].title }}
          </span>
          <span
            class="px-2 py-0.5 rounded text-xs font-medium border shrink-0"
            :style="badgeStyle(sessions[expandedSession].status)"
          >
            {{ sessions[expandedSession].status }}
          </span>
        </div>

        <!-- Session progress bar (task-level) -->
        <div class="w-full bg-n-alpha-3 rounded-full h-1 overflow-hidden">
          <div
            class="h-full rounded-full transition-all duration-300 ease-out"
            :style="{
              width: `${sessions[expandedSession].tasks?.percent ?? 0}%`,
              background: statusColor(sessions[expandedSession].status),
            }"
          />
        </div>
        <div class="text-xs text-n-slate-10">
          {{ sessions[expandedSession].tasks?.done ?? 0 }}/{{ sessions[expandedSession].tasks?.total ?? 0 }} tasks done
        </div>

        <!-- Task list -->
        <div class="space-y-1.5 max-h-48 overflow-y-auto">
          <div
            v-for="task in sessions[expandedSession].tasks?.items ?? []"
            :key="task.key"
            class="flex items-center gap-2 text-xs"
          >
            <i
              class="text-sm flex-shrink-0"
              :class="{
                'ri-checkbox-circle-fill': task.done,
                'ri-checkbox-blank-circle-line text-n-slate-10': !task.done,
              }"
              :style="task.done ? { color: statusColor(sessions[expandedSession].status) } : {}"
            />
            <span
              class="truncate"
              :class="task.done ? 'text-n-slate-9 line-through' : 'text-n-slate-12'"
            >
              {{ task.title }}
            </span>
          </div>
        </div>

        <!-- Open in JIRA link -->
        <button
          v-if="sessions[expandedSession].url"
          class="text-xs text-n-slate-10 hover:text-n-slate-12 hover:underline flex items-center gap-1 mt-1"
          @click="openInJira(sessions[expandedSession].url)"
        >
          <i class="ri-external-link-line" />
          Open in JIRA
        </button>
      </div>

      <!-- Footer: current session + counts -->
      <div class="pt-2 border-t border-n-weak space-y-1.5">
        <div v-if="onboarding.current_session" class="flex justify-between text-xs">
          <span class="text-n-slate-10">Current:</span>
          <span class="text-n-slate-12 font-medium">{{ onboarding.current_session }}</span>
        </div>
        <div class="flex justify-between text-xs">
          <span class="text-n-slate-10">Sessions:</span>
          <span class="text-n-slate-12">
            {{ onboardingData.progress.sessions_done }}/{{ onboardingData.progress.sessions_total }} done
          </span>
        </div>
      </div>

      <!-- View in JIRA button -->
      <NextButton
        v-if="onboarding.url"
        class="w-full"
        size="small"
        variant="ghost"
        @click="openInJira(onboarding.url)"
      >
        <i class="ri-external-link-line mr-1" />
        View in JIRA
      </NextButton>
    </div>
  </div>
</template>

<style scoped>
.onboarding-status-widget {
  min-height: 100px;
}
</style>
