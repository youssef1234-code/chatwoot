<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Spinner from 'shared/components/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

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

const { t } = useI18n();
const isLoading = ref(false);
const onboardingData = ref(null);
const error = ref(null);

// Get company slug from contact custom attributes
const companySlug = computed(() => {
  const customAttributes = props.contact?.custom_attributes || {};
  return customAttributes.company_slug || customAttributes.company || null;
});

// Onboarding phases configuration
const phases = [
  { key: 'initialization', label: 'Initialization', days: 5 },
  { key: 'data_entry', label: 'Data Entry', days: 10 },
  { key: 'training', label: 'Training', days: 7 },
  { key: 'go_live', label: 'Go Live', days: 3 },
];

const currentPhaseIndex = computed(() => {
  if (!onboardingData.value?.current_phase) return 0;
  return phases.findIndex(p => p.key === onboardingData.value.current_phase);
});

const progressPercent = computed(() => {
  if (!onboardingData.value) return 0;
  const completed = currentPhaseIndex.value;
  return Math.round((completed / phases.length) * 100);
});

const statusColor = computed(() => {
  if (!onboardingData.value) return 'bg-gray-100';
  const status = onboardingData.value.status;
  const colors = {
    'active': 'bg-blue-100 text-blue-800',
    'completed': 'bg-green-100 text-green-800',
    'paused': 'bg-yellow-100 text-yellow-800',
    'at_risk': 'bg-red-100 text-red-800',
  };
  return colors[status] || 'bg-gray-100 text-gray-800';
});

const fetchOnboardingStatus = async () => {
  if (!companySlug.value) {
    onboardingData.value = null;
    return;
  }
  
  isLoading.value = true;
  error.value = null;
  
  try {
    // Call PM Orchestrator API to get onboarding status
    const orchestratorUrl = window.chatwoot?.customSettings?.pm_orchestrator_url || 'http://localhost:8000';
    const response = await fetch(`${orchestratorUrl}/api/v1/onboarding/status/${companySlug.value}`);
    
    if (!response.ok) {
      if (response.status === 404) {
        onboardingData.value = null;
        return;
      }
      throw new Error('Failed to fetch onboarding status');
    }
    
    onboardingData.value = await response.json();
  } catch (err) {
    console.error('Failed to fetch onboarding status:', err);
    error.value = 'Failed to load onboarding status';
  } finally {
    isLoading.value = false;
  }
};

const openPlaneEpic = () => {
  if (onboardingData.value?.plane_epic_url) {
    window.open(onboardingData.value.plane_epic_url, '_blank');
  }
};

const formatDate = (dateStr) => {
  if (!dateStr) return 'N/A';
  return new Date(dateStr).toLocaleDateString();
};

watch(() => props.contact?.id, () => {
  fetchOnboardingStatus();
});

onMounted(() => {
  fetchOnboardingStatus();
});
</script>

<template>
  <div class="onboarding-status-widget">
    <!-- Loading State -->
    <div v-if="isLoading" class="flex justify-center p-6">
      <Spinner />
    </div>
    
    <!-- No Company Slug -->
    <div v-else-if="!companySlug" class="p-4 text-center">
      <p class="text-sm text-n-slate-11">
        {{ $t('ONBOARDING.NO_COMPANY_SLUG') }}
      </p>
    </div>
    
    <!-- Error State -->
    <div v-else-if="error" class="p-4 text-center">
      <p class="text-sm text-red-600">{{ error }}</p>
      <NextButton size="tiny" class="mt-2" @click="fetchOnboardingStatus">
        Retry
      </NextButton>
    </div>
    
    <!-- No Onboarding Found -->
    <div v-else-if="!onboardingData" class="p-4 text-center">
      <p class="text-sm text-n-slate-11">
        {{ $t('ONBOARDING.NO_ONBOARDING') }}
      </p>
    </div>
    
    <!-- Onboarding Status -->
    <div v-else class="p-4 space-y-4">
      <!-- Status Badge -->
      <div class="flex items-center justify-between">
        <span
          class="px-3 py-1 rounded-full text-xs font-medium capitalize"
          :class="statusColor"
        >
          {{ onboardingData.status }}
        </span>
        <span class="text-xs text-n-slate-10">
          {{ progressPercent }}% Complete
        </span>
      </div>
      
      <!-- Progress Bar -->
      <div class="w-full bg-n-alpha-2 rounded-full h-2">
        <div
          class="bg-blue-600 h-2 rounded-full transition-all duration-300"
          :style="{ width: `${progressPercent}%` }"
        />
      </div>
      
      <!-- Phase Timeline -->
      <div class="space-y-2">
        <div
          v-for="(phase, index) in phases"
          :key="phase.key"
          class="flex items-center gap-3"
        >
          <div
            class="w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium"
            :class="[
              index < currentPhaseIndex
                ? 'bg-green-100 text-green-800'
                : index === currentPhaseIndex
                ? 'bg-blue-600 text-white'
                : 'bg-n-alpha-2 text-n-slate-10'
            ]"
          >
            <i v-if="index < currentPhaseIndex" class="ri-check-line" />
            <span v-else>{{ index + 1 }}</span>
          </div>
          <div class="flex-1">
            <p
              class="text-sm font-medium"
              :class="[
                index <= currentPhaseIndex
                  ? 'text-n-slate-12'
                  : 'text-n-slate-10'
              ]"
            >
              {{ phase.label }}
            </p>
          </div>
          <span class="text-xs text-n-slate-10">{{ phase.days }} days</span>
        </div>
      </div>
      
      <!-- Key Dates -->
      <div class="pt-3 border-t border-n-weak space-y-2">
        <div class="flex justify-between text-sm">
          <span class="text-n-slate-10">Start Date:</span>
          <span class="text-n-slate-12">{{ formatDate(onboardingData.start_date) }}</span>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-n-slate-10">Expected Go-Live:</span>
          <span class="text-n-slate-12">{{ formatDate(onboardingData.expected_go_live) }}</span>
        </div>
        <div v-if="onboardingData.current_task" class="flex justify-between text-sm">
          <span class="text-n-slate-10">Current Task:</span>
          <span class="text-n-slate-12 truncate ml-2">{{ onboardingData.current_task }}</span>
        </div>
      </div>
      
      <!-- View in Plane Button -->
      <NextButton
        v-if="onboardingData.plane_epic_url"
        class="w-full"
        size="small"
        variant="ghost"
        @click="openPlaneEpic"
      >
        <i class="ri-external-link-line mr-2" />
        View in Plane
      </NextButton>
    </div>
  </div>
</template>

<style scoped>
.onboarding-status-widget {
  min-height: 100px;
}
</style>
