<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import PlaneAPI from 'dashboard/api/integrations/plane';

const props = defineProps({
  projectId: {
    type: String,
    required: true,
  },
  issueId: {
    type: String,
    required: true,
  },
  issueKey: {
    type: String,
    default: '',
  },
  issue: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const isLoading = ref(true);
const isSaving = ref(false);
const isUploadingFile = ref(false);
const fileInput = ref(null);

// Form state
const issueName = ref('');
const selectedStateId = ref('');
const selectedPriority = ref('');
const selectedAssigneeIds = ref([]);
const selectedLabelIds = ref([]);

// Project metadata
const states = ref([]);
const members = ref([]);
const labels = ref([]);
const priorities = [
  { id: 'urgent', name: 'Urgent' },
  { id: 'high', name: 'High' },
  { id: 'medium', name: 'Medium' },
  { id: 'low', name: 'Low' },
  { id: 'none', name: 'None' },
];

const showModal = ref(true);

const closeModal = () => {
  showModal.value = false;
  emit('close');
};

const loadMetadata = async () => {
  isLoading.value = true;
  try {
    // Fetch project metadata (states, members, labels)
    const metaResponse = await PlaneAPI.getProjectMetadata(props.projectId);
    if (metaResponse.data) {
      states.value = metaResponse.data.states || [];
      members.value = metaResponse.data.members || [];
      labels.value = metaResponse.data.labels || [];
    }

    // Fetch current issue details
    const issueResponse = await PlaneAPI.getIssue(
      props.projectId,
      props.issueId
    );
    if (issueResponse.data) {
      const issue = issueResponse.data;
      issueName.value = issue.summary || issue.name || props.issue.name || '';
      selectedPriority.value = issue.priority || props.issue.priority || 'none';

      // Set assignees
      if (issue.assignees && Array.isArray(issue.assignees)) {
        selectedAssigneeIds.value = issue.assignees.map(a =>
          typeof a === 'string' ? a : a.id || a
        );
      }

      // Set labels
      if (issue.labels && Array.isArray(issue.labels)) {
        selectedLabelIds.value = issue.labels.map(l =>
          typeof l === 'string' ? l : l.id || l
        );
      }
    }

    // Try to determine current state_id from detail or from states list
    const currentStateName =
      props.issue.state_name || props.issue.status || '';
    if (currentStateName) {
      const matchedState = states.value.find(
        s => s.name?.toLowerCase() === currentStateName.toLowerCase()
      );
      if (matchedState) {
        selectedStateId.value = matchedState.id;
      }
    }
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.EDIT.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const saveChanges = async () => {
  isSaving.value = true;
  try {
    const updateData = {
      name: issueName.value,
      priority: selectedPriority.value,
    };

    if (selectedStateId.value) {
      updateData.state_id = selectedStateId.value;
    }
    if (selectedAssigneeIds.value.length > 0) {
      updateData.assignee_ids = selectedAssigneeIds.value;
    }
    if (selectedLabelIds.value.length > 0) {
      updateData.label_ids = selectedLabelIds.value;
    }

    await PlaneAPI.updateIssue(props.projectId, props.issueId, updateData);
    useAlert(t('INTEGRATION_SETTINGS.PLANE.EDIT.SAVE_SUCCESS'));
    emit('saved');
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.EDIT.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const onFileSelect = async event => {
  const files = Array.from(event.target.files);
  if (files.length === 0) return;

  isUploadingFile.value = true;
  let successCount = 0;
  let failCount = 0;

  for (const file of files) {
    if (file.size > 10 * 1024 * 1024) {
      useAlert(t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.MAX_SIZE'));
      failCount++;
      continue;
    }
    try {
      await PlaneAPI.addAttachment(props.projectId, props.issueId, file);
      successCount++;
    } catch (error) {
      console.error('Failed to upload attachment:', file.name, error);
      failCount++;
    }
  }

  if (successCount > 0) {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.UPLOAD_SUCCESS'));
  }
  if (failCount > 0) {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.UPLOAD_ERROR'));
  }

  isUploadingFile.value = false;
  if (fileInput.value) fileInput.value.value = '';
};

const toggleAssignee = memberId => {
  const idx = selectedAssigneeIds.value.indexOf(memberId);
  if (idx === -1) {
    selectedAssigneeIds.value.push(memberId);
  } else {
    selectedAssigneeIds.value.splice(idx, 1);
  }
};

const toggleLabel = labelId => {
  const idx = selectedLabelIds.value.indexOf(labelId);
  if (idx === -1) {
    selectedLabelIds.value.push(labelId);
  } else {
    selectedLabelIds.value.splice(idx, 1);
  }
};

onMounted(() => {
  loadMetadata();
});
</script>

<template>
  <woot-modal v-model:show="showModal" :on-close="closeModal" size="medium">
    <div class="flex flex-col h-auto overflow-hidden">
      <!-- Modal Header -->
      <woot-modal-header
        :header-title="t('INTEGRATION_SETTINGS.PLANE.EDIT.TITLE')"
        :header-content="issueKey"
      >
        <div class="flex items-center mt-3">
          <FluentIcon
            icon="edit"
            size="20"
            class="text-indigo-600 dark:text-indigo-400 mr-2"
          />
          <span class="text-sm text-slate-600 dark:text-slate-400">
            {{ t('INTEGRATION_SETTINGS.PLANE.EDIT.SUBTITLE') }}
          </span>
        </div>
      </woot-modal-header>

      <!-- Loading -->
      <div v-if="isLoading" class="flex items-center justify-center py-16 px-8">
        <div
          class="w-8 h-8 border-2 border-indigo-600 border-t-transparent rounded-full animate-spin"
        />
      </div>

      <!-- Edit Form -->
      <div v-else class="overflow-y-auto max-h-[500px] px-8 py-6 space-y-5">
        <!-- Name -->
        <div>
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            {{ t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.NAME.LABEL') }}
          </label>
          <input
            v-model="issueName"
            type="text"
            class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
          />
        </div>

        <!-- State -->
        <div>
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            {{ t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.STATE.LABEL') }}
          </label>
          <select
            v-model="selectedStateId"
            class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
          >
            <option value="">
              {{
                t(
                  'INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.STATE.PLACEHOLDER'
                )
              }}
            </option>
            <option v-for="state in states" :key="state.id" :value="state.id">
              {{ state.name }}
            </option>
          </select>
        </div>

        <!-- Priority -->
        <div>
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            {{
              t(
                'INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.PRIORITY.LABEL'
              )
            }}
          </label>
          <select
            v-model="selectedPriority"
            class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
          >
            <option
              v-for="priority in priorities"
              :key="priority.id"
              :value="priority.id"
            >
              {{ priority.name }}
            </option>
          </select>
        </div>

        <!-- Assignees -->
        <div v-if="members.length > 0">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            {{
              t(
                'INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.ASSIGNEE.LABEL'
              )
            }}
          </label>
          <div
            class="flex flex-wrap gap-2 p-3 border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800"
          >
            <button
              v-for="member in members"
              :key="member.id"
              type="button"
              class="px-3 py-1.5 rounded-full text-xs font-medium border transition-colors"
              :class="
                selectedAssigneeIds.includes(member.id)
                  ? 'bg-indigo-100 text-indigo-700 border-indigo-300 dark:bg-indigo-900/50 dark:text-indigo-300 dark:border-indigo-600'
                  : 'bg-slate-100 text-slate-600 border-slate-200 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-300 dark:border-slate-600'
              "
              @click="toggleAssignee(member.id)"
            >
              {{ member.display_name || member.name || member.email }}
            </button>
          </div>
        </div>

        <!-- Labels -->
        <div v-if="labels.length > 0">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            {{
              t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.LABELS.LABEL')
            }}
          </label>
          <div
            class="flex flex-wrap gap-2 p-3 border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800"
          >
            <button
              v-for="label in labels"
              :key="label.id"
              type="button"
              class="px-3 py-1.5 rounded-full text-xs font-medium border transition-colors"
              :class="
                selectedLabelIds.includes(label.id)
                  ? 'bg-indigo-100 text-indigo-700 border-indigo-300'
                  : 'bg-slate-100 text-slate-600 border-slate-200 hover:bg-slate-200'
              "
              @click="toggleLabel(label.id)"
            >
              <span
                v-if="label.color"
                class="inline-block w-2 h-2 rounded-full mr-1.5"
                :style="{ backgroundColor: label.color }"
              />
              {{ label.name }}
            </button>
          </div>
        </div>

        <!-- Attachments -->
        <div>
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            {{ t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.TITLE') }}
          </label>
          <div class="flex items-center gap-3">
            <input
              ref="fileInput"
              type="file"
              multiple
              class="hidden"
              accept=".jpg,.jpeg,.png,.pdf,.doc,.docx,.txt,.xls,.xlsx,.csv,.zip"
              @change="onFileSelect"
            />
            <NextButton
              size="small"
              variant="ghost"
              color-scheme="secondary"
              :is-loading="isUploadingFile"
              @click="fileInput?.click()"
            >
              <i class="ri-attachment-line mr-1" />
              {{ t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.UPLOAD') }}
            </NextButton>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{ t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.SUPPORTED_FORMATS') }}
            </span>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div
        v-if="!isLoading"
        class="border-t border-slate-200 dark:border-slate-700 px-8 py-4 flex justify-end space-x-3"
      >
        <NextButton
          size="medium"
          variant="ghost"
          color-scheme="secondary"
          @click="closeModal"
        >
          {{ t('INTEGRATION_SETTINGS.PLANE.CANCEL') }}
        </NextButton>
        <NextButton
          size="medium"
          variant="solid"
          color-scheme="primary"
          :is-loading="isSaving"
          @click="saveChanges"
        >
          {{ t('INTEGRATION_SETTINGS.PLANE.EDIT.SAVE') }}
        </NextButton>
      </div>
    </div>
  </woot-modal>
</template>
