<template>
  <div class="space-y-6">
    <!-- Webhook Setup Section -->
    <div class="flex items-start gap-4">
      <div class="flex-shrink-0">
        <fluent-icon icon="webhook" class="text-n-primary" size="24" />
      </div>
      <div class="flex-1">
        <h3 class="text-lg font-semibold text-n-primary mb-1">
          {{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.TITLE') }}
        </h3>
        <p class="text-sm text-n-secondary mb-4">
          {{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.DESCRIPTION') }}
        </p>
        
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-n-primary mb-2">
              {{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.WEBHOOK_URL') }}
            </label>
            <div class="flex items-center gap-2">
              <input
                ref="webhookUrlInput"
                :value="webhookUrl"
                readonly
                class="flex-1 px-3 py-2 rounded text-sm bg-n-subtle text-n-secondary"
              />
              <NextButton
                variant="outline"
                size="sm"
                @click="copyWebhookUrl"
              >
                <fluent-icon icon="copy" size="16" />
                {{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.COPY') }}
              </NextButton>
            </div>
          </div>

          <!-- Webhook Secret -->
          <div>
            <label class="block text-sm font-medium text-n-primary mb-1">
              {{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_LABEL') }}
            </label>
            <p class="text-xs text-n-secondary mb-2">
              {{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_DESCRIPTION') }}
            </p>
            <div class="flex items-center gap-2">
              <input
                v-model="webhookSecret"
                :type="showSecret ? 'text' : 'password'"
                :placeholder="secretPlaceholder"
                class="flex-1 px-3 py-2 rounded text-sm bg-n-subtle"
              />
              <NextButton
                variant="outline"
                size="sm"
                @click="showSecret = !showSecret"
              >
                <fluent-icon :icon="showSecret ? 'eye-off' : 'eye'" size="16" />
              </NextButton>
              <NextButton
                variant="smooth"
                size="sm"
                color-scheme="primary"
                :disabled="isSaving"
                @click="saveWebhookSecret"
              >
                {{ isSaving
                  ? $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SAVING')
                  : $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SAVE_SECRET')
                }}
              </NextButton>
              <NextButton
                v-if="isSecretConfigured"
                variant="outline"
                size="sm"
                color-scheme="alert"
                :disabled="isSaving"
                @click="removeWebhookSecret"
              >
                {{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.REMOVE_SECRET') }}
              </NextButton>
            </div>
            <p v-if="isSecretConfigured && !webhookSecret" class="text-xs text-n-success mt-1">
              ✓ {{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_CONFIGURED') }}
            </p>
          </div>
          
          <div class="text-sm text-n-secondary">
            <p class="font-medium mb-2">
              {{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.INSTRUCTIONS_TITLE') }}
            </p>
            <ol class="list-decimal list-inside space-y-1 ml-4">
              <li>{{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.STEP_1') }}</li>
              <li>{{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.STEP_2') }}</li>
              <li>{{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.STEP_3') }}</li>
              <li>{{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.STEP_4') }}</li>
              <li>{{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.STEP_5') }}</li>
            </ol>
          </div>
          
          <div class="bg-n-amber-4 rounded p-3">
            <div class="flex items-start gap-2">
              <fluent-icon icon="important" class="text-n-amber-12 mt-0.5" size="16" />
              <div class="text-sm text-n-amber-12">
                <p class="font-medium">{{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.NOTE_TITLE') }}</p>
                <p>{{ $t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.NOTE_DESCRIPTION') }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <hr class="border-n-weak" />

    <!-- Status Configuration Section -->
    <div class="flex items-start gap-4">
      <div class="flex-shrink-0">
        <fluent-icon icon="settings" class="text-n-primary" size="24" />
      </div>
      <div class="flex-1">
        <h3 class="text-lg font-semibold text-n-primary mb-1">
          Status Configuration
        </h3>
        <p class="text-sm text-n-secondary mb-4">
          Configure which Plane statuses are considered "done" and set custom colors for each status.
        </p>

        <!-- Loading -->
        <div v-if="isLoadingStatuses" class="flex items-center gap-2 py-4">
          <div class="w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full animate-spin" />
          <span class="text-sm text-n-secondary">Loading Plane statuses...</span>
        </div>

        <div v-else class="space-y-6">
          <!-- Auto-resolve toggle -->
          <div class="flex items-center justify-between py-2">
            <div>
              <label class="block text-sm font-medium text-n-primary">
                Auto-resolve conversations
              </label>
              <p class="text-xs text-n-secondary mt-0.5">
                Automatically resolve linked conversations when a Plane issue reaches a "done" status
              </p>
            </div>
            <label class="relative inline-flex items-center cursor-pointer">
              <input
                v-model="autoResolveConversation"
                type="checkbox"
                class="sr-only peer"
                @change="saveSettings"
              />
              <div class="w-11 h-6 bg-n-slate-5 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-woot-500" />
            </label>
          </div>

          <!-- Done Statuses -->
          <div>
            <label class="block text-sm font-medium text-n-primary mb-1">
              Done Statuses
            </label>
            <p class="text-xs text-n-secondary mb-3">
              Select which Plane statuses mark an issue as "done". Linked conversations will be resolved and agents notified.
            </p>

            <div v-if="planeStates.length > 0" class="space-y-1">
              <label
                v-for="state in planeStates"
                :key="state.id"
                :for="'done-status-' + state.id"
                class="flex items-center gap-3 py-2 px-2 rounded-md hover:bg-n-slate-2 dark:hover:bg-n-solid-2 transition-colors cursor-pointer"
              >
                <input
                  :id="'done-status-' + state.id"
                  v-model="selectedDoneStatuses"
                  type="checkbox"
                  :value="state.name"
                  class="w-4 h-4 text-woot-500 rounded focus:ring-woot-500"
                  @change="saveSettings"
                />
                <span
                  class="w-3 h-3 rounded-full flex-shrink-0"
                  :style="{ backgroundColor: getStatusColor(state) }"
                />
                <span class="text-sm text-n-primary flex-1">{{ state.name }}</span>
                <span class="text-xs text-n-secondary">{{ state.group }}</span>
              </label>
            </div>
            <p v-else class="text-sm text-n-secondary italic py-2">
              No Plane statuses found. Make sure Plane is connected and has projects configured.
            </p>

            <!-- Custom status entry -->
            <div class="mt-3 pt-3 border-t border-n-weak">
              <label class="block text-xs text-n-secondary mb-2">
                Add custom status name
              </label>
              <div class="flex gap-2">
                <input
                  v-model="customStatusInput"
                  type="text"
                  placeholder="e.g. Deployed"
                  class="flex-1 px-3 py-2 rounded text-sm bg-n-subtle"
                  @keyup.enter="addCustomDoneStatus"
                />
                <NextButton
                  variant="smooth"
                  size="sm"
                  color-scheme="primary"
                  @click="addCustomDoneStatus"
                >
                  Add
                </NextButton>
              </div>
            </div>
          </div>

          <!-- Status Colors -->
          <div>
            <label class="block text-sm font-medium text-n-primary mb-1">
              Status Colors
            </label>
            <p class="text-xs text-n-secondary mb-3">
              Customize colors for each Plane status. Applied on issue tags, kanban columns, and analytics.
            </p>

            <div v-if="planeStates.length > 0" class="space-y-1">
              <div
                v-for="state in planeStates"
                :key="'color-' + state.id"
                class="flex items-center gap-3 py-2 px-2 rounded-md hover:bg-n-slate-2 dark:hover:bg-n-solid-2 transition-colors"
              >
                <span
                  class="w-4 h-4 rounded-full flex-shrink-0"
                  :style="{ backgroundColor: getStatusColor(state) }"
                />
                <span class="text-sm text-n-primary flex-1">{{ state.name }}</span>
                <div class="flex items-center gap-2">
                  <input
                    type="color"
                    :value="getStatusColor(state)"
                    class="w-8 h-8 rounded cursor-pointer border-0 p-0"
                    @input="(e) => updateStatusColor(state.name, e.target.value)"
                  />
                  <NextButton
                    v-if="statusColors[state.name]"
                    variant="outline"
                    size="sm"
                    @click="resetStatusColor(state.name)"
                  >
                    Reset
                  </NextButton>
                </div>
              </div>
            </div>
            <p v-else class="text-sm text-n-secondary italic py-2">
              No Plane statuses found.
            </p>
          </div>

          <!-- Completion Mention Configuration -->
          <div>
            <label class="block text-sm font-medium text-n-primary mb-1">
              Completion Mention Settings
            </label>
            <p class="text-xs text-n-secondary mb-3">
              Choose which users are @mentioned in the completion notification message when a Plane issue reaches a done status.
            </p>

            <div class="space-y-1">
              <label
                for="mention-creator"
                class="flex items-center gap-3 py-2 px-2 rounded-md hover:bg-n-slate-2 dark:hover:bg-n-solid-2 transition-colors cursor-pointer"
              >
                <input
                  id="mention-creator"
                  v-model="mentionConfig.issue_creator"
                  type="checkbox"
                  class="w-4 h-4 text-woot-500 rounded focus:ring-woot-500"
                  @change="saveSettings"
                />
                <div>
                  <span class="text-sm text-n-primary">Issue creator</span>
                  <p class="text-xs text-n-secondary">The agent who linked the Plane issue to the conversation</p>
                </div>
              </label>

              <label
                for="mention-assignee"
                class="flex items-center gap-3 py-2 px-2 rounded-md hover:bg-n-slate-2 dark:hover:bg-n-solid-2 transition-colors cursor-pointer"
              >
                <input
                  id="mention-assignee"
                  v-model="mentionConfig.assignee"
                  type="checkbox"
                  class="w-4 h-4 text-woot-500 rounded focus:ring-woot-500"
                  @change="saveSettings"
                />
                <div>
                  <span class="text-sm text-n-primary">Assigned agent</span>
                  <p class="text-xs text-n-secondary">The agent currently assigned to the conversation</p>
                </div>
              </label>

              <label
                for="mention-participating"
                class="flex items-center gap-3 py-2 px-2 rounded-md hover:bg-n-slate-2 dark:hover:bg-n-solid-2 transition-colors cursor-pointer"
              >
                <input
                  id="mention-participating"
                  v-model="mentionConfig.participating_agents"
                  type="checkbox"
                  class="w-4 h-4 text-woot-500 rounded focus:ring-woot-500"
                  @change="saveSettings"
                />
                <div>
                  <span class="text-sm text-n-primary">Participating agents</span>
                  <p class="text-xs text-n-secondary">All agents who sent messages in the conversation</p>
                </div>
              </label>

              <label
                for="mention-inbox"
                class="flex items-center gap-3 py-2 px-2 rounded-md hover:bg-n-slate-2 dark:hover:bg-n-solid-2 transition-colors cursor-pointer"
              >
                <input
                  id="mention-inbox"
                  v-model="mentionConfig.inbox_members"
                  type="checkbox"
                  class="w-4 h-4 text-woot-500 rounded focus:ring-woot-500"
                  @change="saveSettings"
                />
                <div>
                  <span class="text-sm text-n-primary">Inbox members</span>
                  <p class="text-xs text-n-secondary">All agents assigned to the conversation's inbox</p>
                </div>
              </label>
            </div>

            <!-- Static mention list -->
            <div class="mt-3 pt-3 border-t border-n-weak">
              <label class="block text-xs text-n-secondary mb-2">
                Always mention these agents (by email)
              </label>
              <div class="flex flex-wrap gap-1 mb-2">
                <span
                  v-for="email in mentionConfig.static_emails"
                  :key="email"
                  class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs bg-woot-50 text-woot-700 dark:bg-woot-900 dark:text-woot-300"
                >
                  {{ email }}
                  <button
                    class="hover:text-woot-900 dark:hover:text-woot-100"
                    @click="removeStaticEmail(email)"
                  >
                    ×
                  </button>
                </span>
              </div>
              <div class="flex gap-2">
                <input
                  v-model="staticEmailInput"
                  type="email"
                  placeholder="agent@example.com"
                  class="flex-1 px-3 py-2 rounded text-sm bg-n-subtle"
                  @keyup.enter="addStaticEmail"
                />
                <NextButton
                  variant="smooth"
                  size="sm"
                  color-scheme="primary"
                  @click="addStaticEmail"
                >
                  Add
                </NextButton>
              </div>
            </div>
          </div>

          <!-- Save indicator -->
          <div v-if="isSavingSettings" class="flex items-center gap-2 text-sm text-woot-500">
            <div class="w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full animate-spin" />
            Saving settings...
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PlaneAPI from 'dashboard/api/integrations/plane';

const { t } = useI18n();
const currentAccountId = useMapGetter('getCurrentAccountId');
const webhookUrlInput = ref(null);
const webhookSecret = ref('');
const showSecret = ref(false);
const isSaving = ref(false);
const isSecretConfigured = ref(false);

// Status configuration state
const isLoadingStatuses = ref(false);
const isSavingSettings = ref(false);
const planeStates = ref([]);
const selectedDoneStatuses = ref(['Done', 'Completed', 'Closed', 'Cancelled']);
const statusColors = ref({});
const autoResolveConversation = ref(true);
const customStatusInput = ref('');
const staticEmailInput = ref('');
const mentionConfig = ref({
  issue_creator: true,
  assignee: true,
  participating_agents: true,
  inbox_members: false,
  static_emails: [],
});
let saveDebounceTimer = null;

const webhookUrl = computed(() => {
  const accountId = currentAccountId.value;
  const baseUrl = window.location.origin;
  return `${baseUrl}/api/v1/accounts/${accountId}/integrations/plane/webhooks`;
});

const secretPlaceholder = computed(() => {
  return isSecretConfigured.value
    ? t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_PLACEHOLDER_CONFIGURED')
    : t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_PLACEHOLDER');
});

const fetchSecretStatus = async () => {
  try {
    const { data } = await PlaneAPI.getWebhookSecretStatus();
    isSecretConfigured.value = data.configured;
  } catch {
    // Silently fail — integration may not be connected yet
  }
};

const saveWebhookSecret = async () => {
  if (!webhookSecret.value.trim()) {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_EMPTY_ERROR'));
    return;
  }
  isSaving.value = true;
  try {
    await PlaneAPI.updateWebhookSecret(webhookSecret.value.trim());
    isSecretConfigured.value = true;
    webhookSecret.value = '';
    useAlert(t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_SAVED'));
  } catch {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const removeWebhookSecret = async () => {
  isSaving.value = true;
  try {
    await PlaneAPI.updateWebhookSecret('');
    isSecretConfigured.value = false;
    webhookSecret.value = '';
    useAlert(t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_REMOVED'));
  } catch {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.SECRET_SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const copyWebhookUrl = async () => {
  try {
    await navigator.clipboard.writeText(webhookUrl.value);
    useAlert(t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.COPIED_SUCCESS'));
  } catch {
    webhookUrlInput.value?.select();
    document.execCommand('copy');
    useAlert(t('INTEGRATION_SETTINGS.PLANE.WEBHOOK_SETUP.COPIED_SUCCESS'));
  }
};

// -- Status configuration methods --

const fetchPlaneStatuses = async () => {
  isLoadingStatuses.value = true;
  try {
    const { data } = await PlaneAPI.getPlaneStatuses();
    planeStates.value = data.states || data || [];
  } catch (error) {
    console.error('Failed to fetch Plane statuses:', error);
    planeStates.value = [];
  } finally {
    isLoadingStatuses.value = false;
  }
};

const fetchPlaneSettings = async () => {
  try {
    const { data } = await PlaneAPI.getPlaneSettings();
    selectedDoneStatuses.value = data.done_statuses || ['Done', 'Completed', 'Closed', 'Cancelled'];
    statusColors.value = data.status_colors || {};
    autoResolveConversation.value = data.auto_resolve_conversation !== false;
    if (data.mention_config) {
      mentionConfig.value = {
        issue_creator: data.mention_config.issue_creator !== false,
        assignee: data.mention_config.assignee !== false,
        participating_agents: data.mention_config.participating_agents !== false,
        inbox_members: data.mention_config.inbox_members === true,
        static_emails: data.mention_config.static_emails || [],
      };
    }
  } catch {
    // Use defaults
  }
};

const getStatusColor = (state) => {
  return statusColors.value[state.name] || state.color || '#94a3b8';
};

const updateStatusColor = (stateName, color) => {
  statusColors.value[stateName] = color;
  debouncedSaveSettings();
};

const resetStatusColor = (stateName) => {
  delete statusColors.value[stateName];
  statusColors.value = { ...statusColors.value }; // trigger reactivity
  saveSettings();
};

const addCustomDoneStatus = () => {
  const name = customStatusInput.value.trim();
  if (name && !selectedDoneStatuses.value.includes(name)) {
    selectedDoneStatuses.value.push(name);
    customStatusInput.value = '';
    saveSettings();
  }
};

const debouncedSaveSettings = () => {
  clearTimeout(saveDebounceTimer);
  saveDebounceTimer = setTimeout(() => saveSettings(), 600);
};

const saveSettings = async () => {
  isSavingSettings.value = true;
  try {
    await PlaneAPI.updatePlaneSettings({
      done_statuses: selectedDoneStatuses.value,
      status_colors: statusColors.value,
      auto_resolve_conversation: autoResolveConversation.value,
      mention_config: mentionConfig.value,
    });
  } catch {
    useAlert('Failed to save settings');
  } finally {
    isSavingSettings.value = false;
  }
};

const addStaticEmail = () => {
  const email = staticEmailInput.value.trim().toLowerCase();
  if (email && email.includes('@') && !mentionConfig.value.static_emails.includes(email)) {
    mentionConfig.value.static_emails.push(email);
    staticEmailInput.value = '';
    saveSettings();
  }
};

const removeStaticEmail = (email) => {
  mentionConfig.value.static_emails = mentionConfig.value.static_emails.filter(e => e !== email);
  saveSettings();
};

onMounted(() => {
  fetchSecretStatus();
  fetchPlaneStatuses();
  fetchPlaneSettings();
});
</script>
