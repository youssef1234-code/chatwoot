<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import JiraAPI from 'dashboard/api/integrations/jira';
import { resetStatusColors } from '../conversation/jira/helpers/statusColors';

import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import NextSwitch from 'dashboard/components-next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextSpinner from 'dashboard/components-next/spinner/Spinner.vue';
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';

// JIRA statusCategory.colorName → default hex colors
const JIRA_CATEGORY_COLORS = {
  'blue-gray': '#4a6785',
  'medium-gray': '#94a6b8',
  yellow: '#f79232',
  green: '#14892c',
  'warm-red': '#d04437',
  brown: '#815b3a',
};

// Fallback defaults based on status category name
const CATEGORY_DEFAULT_COLORS = {
  'To Do': '#4a6785',
  'In Progress': '#f79232',
  Done: '#14892c',
};

const props = defineProps({
  hookId: {
    type: [Number, String],
    required: true,
  },
});

const isLoading = ref(true);
const isSaving = ref(false);

const projects = ref([]);
const allStatuses = ref([]);

// Connection settings
const siteUrl = ref('');
const deploymentType = ref('data_center');
const email = ref('');
const apiToken = ref('');
const showConnectionEdit = ref(false);

const deploymentOptions = [
  { label: 'Jira Cloud', value: 'cloud' },
  { label: 'Jira Data Center', value: 'data_center' },
];

const isCloud = computed(() => deploymentType.value === 'cloud');

const tokenLabel = computed(() =>
  isCloud.value ? 'API Token' : 'Personal Access Token'
);

const firstLineProjectKey = ref('');
const secondLineProjectKey = ref('');
const allowedIssueTypes = ref([]);
const issueTypeOptions = ref([]);
const isLoadingIssueTypes = ref(false);
const selectedFinalStatuses = ref([]);
const serviceDeskEnabled = ref(true);
const statusColorMapping = ref({});
const onboardingDoneStatuses = ref([]);
const onboardingInProgressStatuses = ref([]);

const projectOptions = computed(() =>
  projects.value.map(p => ({
    value: p.key,
    label: `${p.name} (${p.key})`,
  }))
);

const statusOptions = computed(() =>
  allStatuses.value.map(s => ({
    value: s.name,
    label: s.category ? `${s.name} (${s.category})` : s.name,
  }))
);

const loadSettings = async () => {
  try {
    const response = await JiraAPI.getSettings();
    const settings = response.data;
    firstLineProjectKey.value = settings.first_line_project_key || '';
    secondLineProjectKey.value = settings.second_line_project_key || '';
    allowedIssueTypes.value = settings.allowed_issue_types || [];
    selectedFinalStatuses.value = settings.final_statuses || [];
    serviceDeskEnabled.value = settings.service_desk_enabled !== false;
    statusColorMapping.value = settings.status_color_mapping || {};
    onboardingDoneStatuses.value = settings.onboarding_done_statuses || [];
    onboardingInProgressStatuses.value = settings.onboarding_in_progress_statuses || [];
    // Connection settings
    siteUrl.value = settings.site_url || '';
    deploymentType.value = settings.deployment_type || 'data_center';
    email.value = settings.email || '';
  } catch {
    // Settings might not exist yet, use defaults
  }
};

const loadProjects = async () => {
  try {
    const response = await JiraAPI.getProjects();
    projects.value = (response.data || []).map(p => ({
      id: p.id,
      key: p.key,
      name: p.name,
    }));
  } catch {
    useAlert('Failed to load JIRA projects. Check your connection settings.');
  }
};

// Load the full (unfiltered) list of issue types for the 1st line project so the
// admin can choose which ones are allowed during issue creation.
const loadIssueTypeOptions = async () => {
  if (!firstLineProjectKey.value) {
    issueTypeOptions.value = [];
    return;
  }
  isLoadingIssueTypes.value = true;
  try {
    const response = await JiraAPI.getProjectMetadata(firstLineProjectKey.value, {
      all: true,
    });
    issueTypeOptions.value = (response.data?.issue_types || []).map(type => ({
      value: type.name,
      label: type.name,
    }));
  } catch {
    issueTypeOptions.value = [];
  } finally {
    isLoadingIssueTypes.value = false;
  }
};

const loadStatuses = async () => {
  try {
    const response = await JiraAPI.getStatuses();
    allStatuses.value = (response.data || []).map(s => ({
      id: s.id,
      name: s.name,
      category: s.category,
      color_name: s.color_name,
    }));
    // Initialize default colors for statuses not already mapped
    allStatuses.value.forEach(s => {
      if (!statusColorMapping.value[s.name]) {
        statusColorMapping.value[s.name] =
          JIRA_CATEGORY_COLORS[s.color_name] ||
          CATEGORY_DEFAULT_COLORS[s.category] ||
          '#4a6785';
      }
    });
  } catch {
    useAlert('Failed to load JIRA statuses. Check your connection settings.');
  }
};

const saveSettings = async () => {
  isSaving.value = true;
  try {
    const payload = {
      first_line_project_key: firstLineProjectKey.value,
      second_line_project_key: secondLineProjectKey.value,
      allowed_issue_types: allowedIssueTypes.value,
      final_statuses: selectedFinalStatuses.value,
      service_desk_enabled: serviceDeskEnabled.value,
      status_color_mapping: statusColorMapping.value,
      onboarding_done_statuses: onboardingDoneStatuses.value,
      onboarding_in_progress_statuses: onboardingInProgressStatuses.value,
    };
    // Include connection settings if user edited them
    if (showConnectionEdit.value) {
      payload.site_url = siteUrl.value;
      payload.deployment_type = deploymentType.value;
      if (isCloud.value) payload.email = email.value;
      if (apiToken.value) payload.api_token = apiToken.value;
    }
    await JiraAPI.updateSettings(payload);
    resetStatusColors();
    useAlert('JIRA settings saved successfully!');
    showConnectionEdit.value = false;
    apiToken.value = '';
  } catch {
    useAlert('Failed to save settings. Please try again.');
  } finally {
    isSaving.value = false;
  }
};

// Reload the allowed-issue-type options whenever the 1st line project changes.
watch(firstLineProjectKey, () => {
  loadIssueTypeOptions();
});

onMounted(async () => {
  await loadSettings();
  await Promise.all([loadProjects(), loadStatuses(), loadIssueTypeOptions()]);
  isLoading.value = false;
});
</script>

<template>
  <div
    class="mt-4 p-6 outline outline-1 outline-n-container bg-n-alpha-3 rounded-xl"
  >
    <h3 class="text-lg font-semibold text-n-slate-12 mb-1">
      JIRA Project &amp; Status Configuration
    </h3>
    <p class="text-sm text-n-slate-11 mb-6">
      Configure which projects are used for ticket creation and escalation, and
      which statuses mark an issue as completed.
    </p>

    <div v-if="isLoading" class="flex items-center justify-center py-8 gap-2">
      <NextSpinner :size="20" />
      <span class="text-sm text-n-slate-11">
        Loading projects and statuses from JIRA...
      </span>
    </div>

    <div v-else class="flex flex-col gap-6">
      <!-- Connection Settings (collapsible) -->
      <div class="border border-n-weak rounded-lg p-4">
        <div
          class="flex items-center justify-between cursor-pointer"
          @click="showConnectionEdit = !showConnectionEdit"
        >
          <div>
            <label class="text-sm font-medium text-n-slate-12">
              Connection Settings
            </label>
            <p class="text-xs text-n-slate-10 mt-0.5">
              {{ siteUrl || 'Not configured' }} · {{ deploymentType === 'cloud' ? 'Cloud' : 'Data Center' }}
            </p>
          </div>
          <NextButton
            ghost
            xs
            :icon="showConnectionEdit ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
            :label="showConnectionEdit ? 'Hide' : 'Edit'"
          />
        </div>
        <div v-if="showConnectionEdit" class="mt-4 flex flex-col gap-4">
          <div>
            <label class="mb-1 block text-sm font-medium text-n-slate-12">
              Deployment Type
            </label>
            <ComboBox
              v-model="deploymentType"
              :options="deploymentOptions"
              placeholder="Select deployment type"
            />
          </div>
          <NextInput
            v-model="siteUrl"
            label="Site URL"
            placeholder="https://your-jira.atlassian.net"
          />
          <NextInput
            v-if="isCloud"
            v-model="email"
            label="Email"
            type="email"
            placeholder="you@example.com"
          />
          <NextInput
            v-model="apiToken"
            :label="tokenLabel"
            type="password"
            placeholder="Leave blank to keep current token"
          />
          <p class="text-xs text-n-slate-10 -mt-2">
            Only enter a new token if you want to change it.
          </p>
        </div>
      </div>

      <!-- 1st Line Project -->
      <div>
        <label class="mb-1 block text-sm font-medium text-n-slate-12">
          1st Line Project (Support)
        </label>
        <p class="text-xs text-n-slate-10 mb-2">
          New issues will be created in this project by default.
        </p>
        <ComboBox
          v-model="firstLineProjectKey"
          :options="projectOptions"
          placeholder="Select a project..."
          search-placeholder="Search projects..."
          empty-state="No projects found"
        />
      </div>

      <!-- 2nd Line Project -->
      <div>
        <label class="mb-1 block text-sm font-medium text-n-slate-12">
          2nd Line Project (Escalation)
        </label>
        <p class="text-xs text-n-slate-10 mb-2">
          Issues will be moved to this project when escalated.
        </p>
        <ComboBox
          v-model="secondLineProjectKey"
          :options="projectOptions"
          placeholder="Select a project..."
          search-placeholder="Search projects..."
          empty-state="No projects found"
        />
      </div>

      <!-- Allowed Issue Types (Multi-select) -->
      <div>
        <label class="mb-1 block text-sm font-medium text-n-slate-12">
          Allowed Issue Types
        </label>
        <p class="text-xs text-n-slate-10 mb-2">
          Restrict which issue types agents can pick when creating an issue. Leave
          empty to allow all types. Options come from the 1st Line project.
        </p>
        <p
          v-if="!firstLineProjectKey"
          class="text-xs text-n-amber-11 mb-2"
        >
          Select a 1st Line project first to choose allowed issue types.
        </p>
        <TagMultiSelectComboBox
          v-else
          v-model="allowedIssueTypes"
          :options="issueTypeOptions"
          :placeholder="isLoadingIssueTypes ? 'Loading issue types...' : 'Select issue types...'"
          search-placeholder="Search issue types..."
          empty-state="No issue types found"
        />
      </div>

      <!-- Final Statuses (Multi-select) -->
      <div>
        <label class="mb-1 block text-sm font-medium text-n-slate-12">
          Final Statuses
        </label>
        <p class="text-xs text-n-slate-10 mb-2">
          When a JIRA issue reaches one of these statuses, inbox users will be
          notified.
        </p>
        <TagMultiSelectComboBox
          v-model="selectedFinalStatuses"
          :options="statusOptions"
          placeholder="Select statuses..."
          search-placeholder="Search statuses..."
          empty-state="No statuses found"
        />
      </div>

      <!-- Onboarding: Done Statuses -->
      <div>
        <label class="mb-1 block text-sm font-medium text-n-slate-12">
          Onboarding &mdash; Done Statuses
        </label>
        <p class="text-xs text-n-slate-10 mb-2">
          Sessions/tasks with these statuses are treated as completed (green) in the onboarding widget.
        </p>
        <TagMultiSelectComboBox
          v-model="onboardingDoneStatuses"
          :options="statusOptions"
          placeholder="Select done statuses..."
          search-placeholder="Search statuses..."
          empty-state="No statuses found"
        />
      </div>

      <!-- Onboarding: In-Progress Statuses -->
      <div>
        <label class="mb-1 block text-sm font-medium text-n-slate-12">
          Onboarding &mdash; In Progress Statuses
        </label>
        <p class="text-xs text-n-slate-10 mb-2">
          Sessions/tasks with these statuses are treated as active (blue) in the onboarding widget.
        </p>
        <TagMultiSelectComboBox
          v-model="onboardingInProgressStatuses"
          :options="statusOptions"
          placeholder="Select in-progress statuses..."
          search-placeholder="Search statuses..."
          empty-state="No statuses found"
        />
      </div>

      <!-- Status Color Mapping -->
      <div>
        <label class="mb-1 block text-sm font-medium text-n-slate-12">
          Status Colors
        </label>
        <p class="text-xs text-n-slate-10 mb-2">
          Customize the display color for each JIRA status. Defaults are based
          on JIRA's status category colors.
        </p>
        <div class="grid grid-cols-2 gap-3">
          <div
            v-for="status in allStatuses"
            :key="status.id"
            class="flex items-center gap-2 p-2 rounded-lg bg-n-alpha-2"
          >
            <ColorPicker
              :model-value="statusColorMapping[status.name] || '#94a6b8'"
              @update:model-value="
                val => (statusColorMapping[status.name] = val)
              "
            />
            <span class="text-sm text-n-slate-12 truncate">
              {{ status.name }}
            </span>
          </div>
        </div>
      </div>

      <!-- Service Desk toggle -->
      <div class="flex items-center justify-between">
        <div>
          <label class="text-sm font-medium text-n-slate-12">
            Enable Service Desk Customers
          </label>
          <p class="text-xs text-n-slate-10 mt-0.5">
            Automatically add organization contacts as JIRA Service Desk
            customers.
          </p>
        </div>
        <NextSwitch v-model="serviceDeskEnabled" />
      </div>

      <!-- Save button -->
      <div class="flex justify-end pt-2">
        <NextButton
          label="Save Settings"
          :is-loading="isSaving"
          @click="saveSettings"
        />
      </div>
    </div>
  </div>
</template>
