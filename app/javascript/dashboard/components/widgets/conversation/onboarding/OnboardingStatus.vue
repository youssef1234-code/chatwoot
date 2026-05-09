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

const stageColor = computed(() => {
  const colors = {
    'Completed': 'bg-green-100 text-green-800',
    'In Progress': 'bg-blue-100 text-blue-800',
    'Not Started': 'bg-gray-100 text-gray-800',
    'Partially Done': 'bg-yellow-100 text-yellow-800',
    'All Sessions Done': 'bg-green-100 text-green-800',
  };
  return colors[progressStage.value] || 'bg-gray-100 text-gray-800';
});

const sessionDotClass = (session) => {
  if (session.status === 'Done') return 'bg-green-500 text-white';
  if (session.status === 'In Progress') return 'bg-blue-500 text-white ring-2 ring-blue-300';
  return 'bg-n-alpha-2 text-n-slate-10';
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
      <!-- Header: status + refresh -->
      <div class="flex items-center justify-between">
        <span
          class="px-3 py-1 rounded-full text-xs font-medium"
          :class="stageColor"
        >
          {{ progressStage }}
        </span>
        <div class="flex items-center gap-2">
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
          <span class="text-xs text-n-slate-10 font-medium">
            {{ overallPercent }}%
          </span>
        </div>
      </div>

      <!-- Overall progress bar -->
      <div class="w-full bg-n-alpha-2 rounded-full h-2">
        <div
          class="h-2 rounded-full transition-all duration-500"
          :class="overallPercent === 100 ? 'bg-green-500' : 'bg-blue-500'"
          :style="{ width: `${overallPercent}%` }"
        />
      </div>

      <!-- Session dots row -->
      <div class="flex items-center justify-between gap-1">
        <button
          v-for="(session, idx) in sessions"
          :key="session.key"
          class="relative flex items-center justify-center w-8 h-8 rounded-full text-xs font-bold cursor-pointer transition-all duration-200 hover:scale-110"
          :class="sessionDotClass(session)"
          :title="`${session.title} — ${session.status}`"
          @click="toggleSession(idx)"
        >
          <i v-if="session.status === 'Done'" class="ri-check-line text-sm" />
          <span v-else>{{ session.number }}</span>
        </button>
      </div>

      <!-- Connecting line under dots -->
      <div v-if="sessions.length > 1" class="relative h-1 -mt-3 mx-4">
        <div class="absolute inset-0 bg-n-alpha-2 rounded" />
        <div
          class="absolute left-0 top-0 h-full rounded transition-all duration-500"
          :class="overallPercent === 100 ? 'bg-green-500' : 'bg-blue-500'"
          :style="{ width: `${(onboardingData.progress.sessions_done / sessions.length) * 100}%` }"
        />
      </div>

      <!-- Expanded session detail -->
      <div
        v-if="expandedSession !== null && sessions[expandedSession]"
        class="border border-n-weak rounded-lg p-3 space-y-3 mt-2"
      >
        <div class="flex items-center justify-between">
          <span class="text-sm font-semibold text-n-slate-12">
            {{ sessions[expandedSession].title }}
          </span>
          <span
            class="px-2 py-0.5 rounded text-xs font-medium"
            :class="sessions[expandedSession].status === 'Done' ? 'bg-green-100 text-green-800' : sessions[expandedSession].status === 'In Progress' ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800'"
          >
            {{ sessions[expandedSession].status }}
          </span>
        </div>

        <!-- Session progress bar -->
        <div class="w-full bg-n-alpha-2 rounded-full h-1.5">
          <div
            class="h-1.5 rounded-full transition-all duration-300"
            :class="sessions[expandedSession].tasks.percent === 100 ? 'bg-green-500' : 'bg-blue-500'"
            :style="{ width: `${sessions[expandedSession].tasks.percent}%` }"
          />
        </div>
        <div class="text-xs text-n-slate-10">
          {{ sessions[expandedSession].tasks.done }}/{{ sessions[expandedSession].tasks.total }} tasks done
        </div>

        <!-- Task list -->
        <div class="space-y-1.5 max-h-48 overflow-y-auto">
          <div
            v-for="task in sessions[expandedSession].tasks.items"
            :key="task.key"
            class="flex items-center gap-2 text-xs"
          >
            <i
              :class="task.done ? 'ri-checkbox-circle-fill text-green-500' : 'ri-checkbox-blank-circle-line text-n-slate-10'"
              class="text-sm flex-shrink-0"
            />
            <span
              :class="task.done ? 'text-n-slate-10 line-through' : 'text-n-slate-12'"
              class="truncate"
            >
              {{ task.title }}
            </span>
          </div>
        </div>

        <!-- Open in JIRA link -->
        <button
          v-if="sessions[expandedSession].url"
          class="text-xs text-blue-600 hover:underline flex items-center gap-1 mt-1"
          @click="openInJira(sessions[expandedSession].url)"
        >
          <i class="ri-external-link-line" />
          Open in JIRA
        </button>
      </div>

      <!-- Current session + onboarding link -->
      <div class="pt-3 border-t border-n-weak space-y-2">
        <div v-if="onboarding.current_session" class="flex justify-between text-sm">
          <span class="text-n-slate-10">Current:</span>
          <span class="text-n-slate-12 font-medium">{{ onboarding.current_session }}</span>
        </div>
        <div class="flex justify-between text-sm">
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
        <i class="ri-external-link-line mr-2" />
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
