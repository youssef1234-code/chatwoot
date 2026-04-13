<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useStore } from 'vuex';
import PlaneAPI from 'dashboard/api/integrations/plane';
import Input from 'dashboard/components-next/input/Input.vue';
import Textarea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SearchableDropdown from '../shared/SearchableDropdown.vue';
import { parsePlaneAPIErrorResponse, getPriorityInfo } from './helpers/apiErrorHelper';

const PLANE_EVENTS = {
  CREATE_ISSUE: 'Created Plane Issue',
};

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'issue-created']);

const { t } = useI18n();
const store = useStore();

// Get account ID from store
const accountId = computed(() => store.getters.getCurrentAccountId);

// Form state
const formState = ref({
  project_id: '',
  name: props.title || '',
  description_html: props.description || '',
  state_id: '',
  assignee_ids: [],
  priority: 'none',
  labels: []
});

// Attachment state
const attachments = ref([]);
const fileInput = ref(null);

// Data
const projects = ref([]);
const states = ref([]);
const members = ref([]);
const labels = ref([]);
const isLoading = ref(false);
const isCreating = ref(false);

// Priority options
const priorities = [
  { id: 'urgent', name: 'Urgent' },
  { id: 'high', name: 'High' },
  { id: 'medium', name: 'Medium' },
  { id: 'low', name: 'Low' },
  { id: 'none', name: 'None' },
];

// Validation rules
const rules = {
  name: { required },
  project_id: { required },
};

const v$ = useVuelidate(rules, formState);

// Computed properties
const nameError = computed(() =>
  v$.value.name.$error
    ? t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.NAME.REQUIRED_ERROR')
    : ''
);

const projectError = computed(() =>
  v$.value.project_id.$error
    ? t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.PROJECT.REQUIRED_ERROR')
    : ''
);

const dropdowns = computed(() => [
  {
    type: 'project_id',
    label: 'INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.PROJECT.LABEL',
    items: projects.value,
    placeholder: 'INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.PROJECT.SEARCH',
    error: projectError.value,
  },
  {
    type: 'state_id',
    label: 'INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.STATE.LABEL',
    items: states.value,
    placeholder: 'INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.STATE.SEARCH',
    error: '',
  },
  {
    type: 'priority',
    label: 'INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.PRIORITY.LABEL',
    items: priorities,
    placeholder: 'INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.PRIORITY.SEARCH',
    error: '',
  },
]);

const isSubmitDisabled = computed(() => {
  return v$.value.$invalid || isCreating.value;
});

// Methods
const onClose = () => emit('close');

const getProjects = async () => {
  try {
    const response = await PlaneAPI.getProjects();
    projects.value = response.data.map(project => ({
      id: project.id,
      name: `${project.name} (${project.identifier})`,
      identifier: project.identifier
    }));
  } catch (error) {
    const errorMessage = parsePlaneAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.LOADING_PROJECTS_ERROR')
    );
    useAlert(errorMessage);
  }
};

const getProjectMetadata = async () => {
  if (!formState.value.project_id) return;

  try {
    const response = await PlaneAPI.getProjectMetadata(formState.value.project_id);
    
    states.value = (response.data.states || []).map(state => ({
      id: state.id,
      name: state.name,
      color: state.color
    }));

    members.value = (response.data.members || []).map(member => ({
      id: member.id,
      name: member.display_name || member.email
    }));

    labels.value = (response.data.labels || []).map(label => ({
      id: label.id,
      name: label.name,
      color: label.color
    }));

    // Set default state if available
    if (states.value.length > 0 && !formState.value.state_id) {
      const defaultState = states.value.find(s => s.name.toLowerCase() === 'backlog') || states.value[0];
      formState.value.state_id = defaultState.id;
    }
  } catch (error) {
    const errorMessage = parsePlaneAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.LOADING_PROJECT_ENTITIES_ERROR')
    );
    useAlert(errorMessage);
  }
};

const onSelectItem = async (type, item) => {
  formState.value[type] = item ? item.id : '';
  
  if (type === 'project_id') {
    // Reset dependent fields when project changes
    formState.value.state_id = '';
    formState.value.assignee_ids = [];
    states.value = [];
    members.value = [];
    labels.value = [];
    
    if (item) {
      await getProjectMetadata();
    }
  }
};

// File upload methods
const onFileSelect = (event) => {
  const files = Array.from(event.target.files);
  files.forEach(file => {
    if (file.size > 10 * 1024 * 1024) { // 10MB limit
      useAlert(t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.MAX_SIZE'));
      return;
    }
    attachments.value.push({
      id: Date.now() + Math.random(),
      file: file,
      name: file.name,
      size: file.size
    });
  });
  
  // Reset file input
  if (fileInput.value) {
    fileInput.value.value = '';
  }
};

const removeAttachment = (attachmentId) => {
  attachments.value = attachments.value.filter(att => att.id !== attachmentId);
};

const formatFileSize = (bytes) => {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

const createIssue = async () => {
  await v$.value.$validate();
  if (v$.value.$error) return;

  try {
    isCreating.value = true;
    const payload = {
      ...formState.value,
      description_html: `<p>${formState.value.description_html || ''}</p>`,
      conversation_id: props.conversationId
    };

    const response = await PlaneAPI.createIssue(payload);
    const issue = response.data;
    
    // Upload attachments if any
    if (attachments.value.length > 0) {
      for (const attachment of attachments.value) {
        try {
          await PlaneAPI.addAttachment(formState.value.project_id, issue.id, attachment.file);
        } catch (attachmentError) {
          console.error('Failed to upload attachment:', attachment.name, attachmentError);
          // Continue with other attachments even if one fails
        }
      }
    }

    useTrack(PLANE_EVENTS.CREATE_ISSUE);
    useAlert(t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.CREATE_SUCCESS'));
    
    // Emit event for escalation workflow
    emit('issue-created', {
      id: issue.id,
      name: formState.value.name,
      ...issue
    });
    
    // Emit event for other components to update
    window.dispatchEvent(new CustomEvent('plane:issues-updated'));
    
    onClose();
  } catch (error) {
    const errorMessage = parsePlaneAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.CREATE_ERROR')
    );
    useAlert(errorMessage);
  } finally {
    isCreating.value = false;
  }
};

onMounted(() => {
  getProjects();
});
</script>

<template>
  <div class="flex flex-col p-6 min-h-[400px]">
    <div class="flex-1 overflow-y-auto space-y-4">
      <!-- Name/Title -->
      <Input
        v-model="formState.name"
        :label="$t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.NAME.LABEL')"
        :placeholder="$t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.NAME.PLACEHOLDER')"
        :message="nameError"
        :messageType="nameError ? 'error' : 'info'"
        required
      />

      <!-- Description -->
      <Textarea
        v-model="formState.description_html"
        :label="$t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.FORM.DESCRIPTION.PLACEHOLDER')"
        :rows="3"
        :resize="true"
      />

      <!-- Dropdowns -->
      <SearchableDropdown
        v-for="dropdown in dropdowns"
        :key="dropdown.type"
        :label="$t(dropdown.label)"
        :placeholder="$t(dropdown.placeholder)"
        :items="dropdown.items"
        :value="formState[dropdown.type]"
        :error-message="dropdown.error"
        @select="item => onSelectItem(dropdown.type, item)"
      />

      <!-- File Attachments -->
      <div class="space-y-2">
        <label class="block text-sm font-medium text-n-slate-12">
          {{ $t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.TITLE') }}
        </label>
        
        <!-- File Upload Button -->
        <div class="flex items-center gap-2">
          <input
            ref="fileInput"
            type="file"
            multiple
            class="hidden"
            accept=".jpg,.jpeg,.png,.pdf,.doc,.docx,.txt"
            @change="onFileSelect"
          />
          <Button
            ghost
            slate
            size="small"
            :label="$t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.UPLOAD')"
            @click="fileInput?.click()"
          >
            <template #icon>
              <i class="ri-attachment-line" />
            </template>
          </Button>
          <span class="text-xs text-n-slate-10">
            {{ $t('INTEGRATION_SETTINGS.PLANE.ATTACHMENTS.SUPPORTED_FORMATS') }}
          </span>
        </div>

        <!-- Attachment List -->
        <div v-if="attachments.length > 0" class="space-y-2">
          <div
            v-for="attachment in attachments"
            :key="attachment.id"
            class="flex items-center justify-between p-2 bg-slate-50 dark:bg-slate-700 rounded"
          >
            <div class="flex items-center gap-2">
              <i class="ri-file-line text-slate-500 dark:text-slate-400" />
              <span class="text-sm text-slate-900 dark:text-slate-100">{{ attachment.name }}</span>
              <span class="text-xs text-slate-500 dark:text-slate-400">({{ formatFileSize(attachment.size) }})</span>
            </div>
            <button
              type="button"
              class="text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300"
              @click="removeAttachment(attachment.id)"
            >
              <i class="ri-close-line" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div class="flex justify-end gap-3 pt-4 border-t border-slate-200 dark:border-slate-600">
      <Button ghost slate :label="$t('INTEGRATION_SETTINGS.PLANE.CANCEL')" @click="onClose" />
      <Button
        blue
        :label="$t('INTEGRATION_SETTINGS.PLANE.CREATE')"
        :loading="isCreating"
        :disabled="isSubmitDisabled"
        @click="createIssue"
      />
    </div>
  </div>
</template>
