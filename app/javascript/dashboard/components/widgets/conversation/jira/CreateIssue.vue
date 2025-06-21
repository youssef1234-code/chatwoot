<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useStore } from 'vuex';
import JiraAPI from 'dashboard/api/integrations/jira';
import Input from 'dashboard/components-next/input/Input.vue';
import Textarea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SearchableDropdown from './SearchableDropdown.vue';
import { parseJiraAPIErrorResponse } from './helpers/apiErrorHelper';
import account from '../../../../api/account';

const JIRA_EVENTS = {
  CREATE_ISSUE: 'Created Jira Issue',
};

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

// Get account ID from store
const accountId = computed(() => store.getters.getCurrentAccountId);

// Form state
const formState = ref({
  project_key: '',
  summary: '',
  description: '',
  issue_type_id: '',
  assignee_id: '',
  priority_id: '',
  environment: '',
  labels: []
});

// Attachment state
const attachments = ref([]);
const fileInput = ref(null);

// Data
const projects = ref([]);
const issueTypes = ref([]);
const users = ref([]);
const priorities = ref([]);
const isLoading = ref(false);
const isCreating = ref(false);

// Validation rules
const rules = {
  summary: { required },
  project_key: { required },
  issue_type_id: { required }
};

const v$ = useVuelidate(rules, formState);

// Computed properties
const summaryError = computed(() =>
  v$.value.summary.$error
    ? t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.SUMMARY.REQUIRED_ERROR')
    : ''
);

const projectError = computed(() =>
  v$.value.project_key.$error
    ? t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.PROJECT.REQUIRED_ERROR')
    : ''
);

const issueTypeError = computed(() =>
  v$.value.issue_type_id.$error
    ? t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.ISSUE_TYPE.REQUIRED_ERROR')
    : ''
);

const dropdowns = computed(() => [
  {
    type: 'project_key',
    label: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.PROJECT.LABEL',
    items: projects.value,
    placeholder: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.PROJECT.SEARCH',
    error: projectError.value,
  },
  {
    type: 'issue_type_id',
    label: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.ISSUE_TYPE.LABEL',
    items: issueTypes.value,
    placeholder: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.ISSUE_TYPE.SEARCH',
    error: issueTypeError.value,
  },
  {
    type: 'assignee_id',
    label: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.ASSIGNEE.LABEL',
    items: users.value,
    placeholder: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.ASSIGNEE.SEARCH',
    error: '',
  },
  {
    type: 'priority_id',
    label: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.PRIORITY.LABEL',
    items: priorities.value,
    placeholder: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.PRIORITY.SEARCH',
    error: '',
  },
  {
    type: 'environment',
    label: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.ENVIRONMENT.LABEL',
    items: [
      { id: 'development', name: 'Development' },
      { id: 'staging', name: 'Staging' },
      { id: 'production', name: 'Production' },
      { id: 'testing', name: 'Testing' },
      { id: 'qa', name: 'QA' }
    ],
    placeholder: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.ENVIRONMENT.SEARCH',
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
    const response = await JiraAPI.getProjects();
    projects.value = response.data.map(project => ({
      id: project.key,
      name: `${project.name} (${project.key})`,
      key: project.key
    }));
  } catch (error) {
    const errorMessage = parseJiraAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.LOADING_PROJECTS_ERROR')
    );
    useAlert(errorMessage);
  }
};

const getProjectMetadata = async () => {
  if (!formState.value.project_key) return;

  try {
    const response = await JiraAPI.getProjectMetadata(formState.value.project_key);
    
    issueTypes.value = response.data.issue_types.map(type => ({
      id: type.id,
      name: type.name
    }));

    users.value = response.data.users.map(user => ({
      id: user.accountId,
      name: user.displayName
    }));

    priorities.value = response.data.priorities.map(priority => ({
      id: priority.id,
      name: priority.name
    }));
  } catch (error) {
    const errorMessage = parseJiraAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.LOADING_PROJECT_ENTITIES_ERROR')
    );
    useAlert(errorMessage);
  }
};

const onSelectItem = async (type, item) => {
  formState.value[type] = item ? item.id : '';
  
  if (type === 'project_key') {
    // Reset dependent fields when project changes
    formState.value.issue_type_id = '';
    formState.value.assignee_id = '';
    issueTypes.value = [];
    users.value = [];
    
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
      useAlert(t('INTEGRATION.JIRA.ATTACHMENTS.MAX_SIZE'));
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
    
    // Enhance description with conversation context
    const conversationContext = `

---
**Conversation Context:**
- Conversation ID: #${props.conversationId}
- Created from Chatwoot conversation
- Link to conversation: ${window.location.origin}/app/accounts/${accountId}/conversations/${props.conversationId}
`;

    const payload = {
      ...formState.value,
      description: (formState.value.description || '') + conversationContext,
      conversation_id: props.conversationId
    };

    const response = await JiraAPI.createIssue(payload);
    const issueKey = response.data.key;
    
    // Upload attachments if any
    if (attachments.value.length > 0) {
      for (const attachment of attachments.value) {
        try {
          await JiraAPI.addAttachment(issueKey, attachment.file);
        } catch (attachmentError) {
          console.error('Failed to upload attachment:', attachment.name, attachmentError);
          // Continue with other attachments even if one fails
        }
      }
    }

    useTrack(JIRA_EVENTS.CREATE_ISSUE);
    useAlert(t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.CREATE_SUCCESS'));
    
    // Emit event for other components to update
    window.dispatchEvent(new CustomEvent('jira:issues-updated'));
    
    onClose();
  } catch (error) {
    const errorMessage = parseJiraAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.CREATE_ERROR')
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
  <div class="flex flex-col h-full p-6">
    <div class="flex-1 overflow-y-auto space-y-4">
      <!-- Summary -->
      <Input
        v-model="formState.summary"
        :label="$t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.SUMMARY.LABEL')"
        :placeholder="$t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.SUMMARY.PLACEHOLDER')"
        :message="summaryError"
        :messageType="summaryError ? 'error' : 'info'"
        required
      />

      <!-- Description -->
      <Textarea
        v-model="formState.description"
        :label="$t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.DESCRIPTION.PLACEHOLDER')"
        :rows="3"
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
          {{ $t('INTEGRATION.JIRA.ATTACHMENTS.TITLE') }}
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
            :label="$t('INTEGRATION.JIRA.ATTACHMENTS.UPLOAD')"
            @click="fileInput?.click()"
          >
            <template #icon>
              <i class="ri-attachment-line" />
            </template>
          </Button>
          <span class="text-xs text-n-slate-10">
            {{ $t('INTEGRATION.JIRA.ATTACHMENTS.SUPPORTED_FORMATS') }}
          </span>
        </div>

        <!-- Attachment List -->
        <div v-if="attachments.length > 0" class="space-y-2">
          <div
            v-for="attachment in attachments"
            :key="attachment.id"
            class="flex items-center justify-between p-2 bg-n-alpha-1 rounded"
          >
            <div class="flex items-center gap-2">
              <i class="ri-file-line text-n-slate-10" />
              <span class="text-sm">{{ attachment.name }}</span>
              <span class="text-xs text-n-slate-8">({{ formatFileSize(attachment.size) }})</span>
            </div>
            <button
              type="button"
              class="text-red-500 hover:text-red-700"
              @click="removeAttachment(attachment.id)"
            >
              <i class="ri-close-line" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div class="flex justify-end gap-3 pt-4 border-t border-n-weak">
      <Button ghost slate :label="$t('INTEGRATION_SETTINGS.JIRA.CANCEL')" @click="onClose" />
      <Button
        blue
        :label="$t('INTEGRATION_SETTINGS.JIRA.CREATE')"
        :loading="isCreating"
        :disabled="isSubmitDisabled"
        @click="createIssue"
      />
    </div>
  </div>
</template>
