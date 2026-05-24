<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useStore } from 'vuex';
import JiraAPI from 'dashboard/api/integrations/jira';
import OpenaiAPI from 'dashboard/api/integrations/openapi';
import Input from 'dashboard/components-next/input/Input.vue';
import Textarea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SearchableDropdown from '../shared/SearchableDropdown.vue';
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
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
  selectedMessageIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'issue-created']);

const { t } = useI18n();
const store = useStore();

// Get account ID from store
const accountId = computed(() => store.getters.getCurrentAccountId);

// Form state
const formState = ref({
  project_key: '',
  summary: props.title || '',
  description: props.description || '',
  issue_type_id: '',
  priority_id: '',
  category: '',
  labels: []
});

// Attachment state
const attachments = ref([]);
const fileInput = ref(null);
const excludedMessageAttachmentIds = ref(new Set());

// Data
const projects = ref([]);
const issueTypes = ref([]);
const users = ref([]);
const priorities = ref([]);
const isLoading = ref(false);
const isCreating = ref(false);
// When a 1st line project is configured, new issues are forced into it and the
// project selector is locked. Escalation is the only way to reach the 2nd line.
const firstLineProjectKey = ref('');
const isProjectLocked = computed(() => !!firstLineProjectKey.value);

// Validation rules
const rules = {
  summary: { required },
  project_key: { required },
  issue_type_id: { required },
  category: { required }
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

const categoryError = computed(() =>
  v$.value.category.$error
    ? t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.CATEGORY.REQUIRED_ERROR')
    : ''
);

// Ticket categories from account settings
const currentAccount = computed(() => {
  const id = store.getters.getCurrentAccountId;
  const acct = store.getters['accounts/getAccount'](id);
  return acct && Object.keys(acct).length > 0 ? acct : {};
});
const availableCategories = computed(() => {
  const categories = currentAccount.value?.settings?.ticket_categories || [
    'General Support', 'Technical Issue', 'Billing', 'Feature Request',
    'Bug Report', 'Account Management', 'Sales Inquiry'
  ];
  // Filter out empty/blank entries and deduplicate
  const filtered = [...new Set(categories.filter(c => c && c.trim()))];
  return filtered.map(c => ({ id: c, name: c }));
});

const dropdowns = computed(() => [
  {
    type: 'project_key',
    label: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.PROJECT.LABEL',
    items: projects.value,
    placeholder: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.PROJECT.SEARCH',
    error: projectError.value,
    disabled: isProjectLocked.value,
  },
  {
    type: 'issue_type_id',
    label: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.ISSUE_TYPE.LABEL',
    items: issueTypes.value,
    placeholder: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.ISSUE_TYPE.SEARCH',
    error: issueTypeError.value,
  },
  {
    type: 'priority_id',
    label: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.PRIORITY.LABEL',
    items: priorities.value,
    placeholder: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.PRIORITY.SEARCH',
    error: '',
  },
  {
    type: 'category',
    label: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.CATEGORY.LABEL',
    items: availableCategories.value,
    placeholder: 'INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.FORM.CATEGORY.SEARCH',
    error: categoryError.value,
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

    // Auto-select and lock to the 1st line project if configured
    try {
      const settingsResponse = await JiraAPI.getSettings();
      const firstLineKey = settingsResponse.data?.first_line_project_key;
      if (firstLineKey) {
        const firstLineProject = projects.value.find(p => p.key === firstLineKey);
        if (firstLineProject) {
          firstLineProjectKey.value = firstLineProject.id;
          if (!formState.value.project_key) {
            formState.value.project_key = firstLineProject.id;
            await getProjectMetadata();
          }
        }
      }
    } catch {
      // Settings endpoint not available or failed, continue normally
    }
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

    // Auto-select first issue type (e.g. Bug or Task)
    if (issueTypes.value.length > 0 && !formState.value.issue_type_id) {
      formState.value.issue_type_id = issueTypes.value[0].id;
    }

    // Auto-select priority: prefer 'Medium', fallback to first
    if (priorities.value.length > 0 && !formState.value.priority_id) {
      const medium = priorities.value.find(p => p.name.toLowerCase() === 'medium');
      formState.value.priority_id = medium ? medium.id : priorities.value[0].id;
    }
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
    formState.value.priority_id = '';
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

const removeMessageAttachment = (attId) => {
  excludedMessageAttachmentIds.value = new Set([...excludedMessageAttachmentIds.value, attId]);
};

const getAttachmentName = (att) => {
  if (att.data_url) {
    try {
      const url = new URL(att.data_url, window.location.origin);
      const parts = url.pathname.split('/');
      const last = parts[parts.length - 1];
      if (last && last.includes('.')) return decodeURIComponent(last);
    } catch (e) { /* fallback */ }
  }
  const ext = att.extension ? `.${att.extension}` : '';
  return `${att.file_type || 'file'}${ext}`;
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
      description: (formState.value.description || ''),
      conversation_id: props.conversationId,
      labels: [...(formState.value.labels || []), formState.value.category].filter(Boolean),
      message_ids: props.selectedMessageIds || [],
    };

    const response = await JiraAPI.createIssue(payload);
    const issueKey = response.data.key;
    
    // Upload manually attached files
    if (attachments.value.length > 0) {
      for (const attachment of attachments.value) {
        try {
          await JiraAPI.addAttachment(issueKey, attachment.file);
        } catch (attachmentError) {
          console.error('Failed to upload attachment:', attachment.name, attachmentError);
        }
      }
    }

    // Upload non-audio attachments from selected messages (skip fully excluded)
    if (props.selectedMessageIds && props.selectedMessageIds.length > 0) {
      const conversation = currentChat.value;
      const allMessages = conversation?.messages || [];
      const excluded = excludedMessageAttachmentIds.value;
      const msgsWithAttachments = props.selectedMessageIds
        .map(id => allMessages.find(m => m.id === id))
        .filter(Boolean)
        .filter(msg =>
          (msg.attachments || []).some(a => a.file_type !== 'audio' && !excluded.has(a.id))
        );
      if (msgsWithAttachments.length > 0) {
        try {
          await JiraAPI.uploadMessageAttachments(
            issueKey,
            props.conversationId,
            msgsWithAttachments.map(m => m.id)
          );
        } catch (uploadErr) {
          console.error('Failed to upload message attachments:', uploadErr);
        }
      }
    }

    useTrack(JIRA_EVENTS.CREATE_ISSUE);
    useAlert(t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.CREATE_SUCCESS'));
    
    // Emit event for escalation workflow
    emit('issue-created', {
      key: issueKey,
      summary: formState.value.summary,
      ...response.data
    });
    
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

// AI generation
const isGeneratingWithAI = ref(false);

/**
 * Determine sender label for AI context.
 * Uses wa_sender_role from content_attributes if available (set by bridge for configured team members).
 * Falls back to message_type: 0 = Customer, else Agent.
 */
const getSenderLabel = (msg) => {
  const attrs = msg.content_attributes || {};
  const role = attrs.wa_sender_role || attrs.waSenderRole;
  if (role) return role;
  const isTeam = attrs.wa_is_team_member || attrs.waIsTeamMember;
  if (isTeam) return 'Team';
  return msg.message_type === 0 ? 'Customer' : 'Agent';
};
const currentChat = computed(() => store.getters.getSelectedChat);

// Attachments from selected messages (flattened)
const messageAttachments = computed(() => {
  if (!props.selectedMessageIds || props.selectedMessageIds.length === 0) return [];
  const conversation = currentChat.value;
  const allMessages = conversation?.messages || [];
  return props.selectedMessageIds
    .map(id => allMessages.find(m => m.id === id))
    .filter(Boolean)
    .flatMap(msg => (msg.attachments || []).filter(a => a.file_type !== 'audio'))
    .filter(a => !excludedMessageAttachmentIds.value.has(a.id));
});

const generateWithAI = async () => {
  if (isGeneratingWithAI.value || isCreating.value) return;

  isGeneratingWithAI.value = true;
  try {
    const integrations = store.getters['integrations/getAppIntegrations'];
    const openaiHook = integrations.find(
      hook => hook.id === 'openai' && hook.enabled
    );
    if (!openaiHook?.hooks?.[0]?.id) {
      throw new Error('OpenAI integration is not configured. Enable it in Settings → Integrations.');
    }

    const conversation = currentChat.value;
    const allMessages = conversation?.messages || [];

    // Use selectedMessageIds (array of IDs) if available, otherwise fall back to recent messages
    const hasSelectedMessages = props.selectedMessageIds && props.selectedMessageIds.length > 0;

    let messagesContent;
    if (hasSelectedMessages) {
      // Get message objects directly by their IDs
      const selectedMessages = props.selectedMessageIds
        .map(id => allMessages.find(m => m.id === id))
        .filter(Boolean);

      if (selectedMessages.length === 0) {
        throw new Error('Selected messages not found in conversation.');
      }

      // Transcribe untranscribed audio in selected messages
      const audioMessageIds = selectedMessages
        .filter(msg =>
          (msg.attachments || []).some(
            a => a.file_type === 'audio' && !a.transcribed_text
          )
        )
        .map(msg => msg.id);

      if (audioMessageIds.length > 0) {
        try {
          const transcribeResponse = await JiraAPI.transcribeAudio(audioMessageIds);
          const transcriptions = transcribeResponse.data?.transcriptions || {};
          selectedMessages.forEach(msg => {
            (msg.attachments || []).forEach(a => {
              if (a.file_type === 'audio' && !a.transcribed_text && transcriptions[a.id]) {
                a.transcribed_text = transcriptions[a.id];
              }
            });
          });
        } catch {
          // Continue without transcriptions if it fails
        }
      }

      messagesContent = selectedMessages
        .map(msg => {
          const senderRole = getSenderLabel(msg);
          const attrs = msg.content_attributes || {};
          const name = attrs.wa_team_member_name || attrs.waTeamMemberName || msg.sender?.name || attrs.wa_sender_name || 'Unknown';
          let text = msg.content || '';
          const audioTranscriptions = (msg.attachments || [])
            .filter(a => a.file_type === 'audio' && a.transcribed_text)
            .map(a => `[Audio transcription: ${a.transcribed_text}]`);
          if (audioTranscriptions.length > 0) {
            text = text
              ? `${text}\n${audioTranscriptions.join('\n')}`
              : audioTranscriptions.join('\n');
          }
          return text ? `${name} (${senderRole}): ${text}` : '';
        })
        .filter(m => m.trim())
        .join('\n\n');
    } else {
      // No messages selected — use last 30 messages from conversation
      if (allMessages.length === 0) {
        throw new Error('No conversation messages available to generate from.');
      }
      const recentMessages = allMessages.slice(-30);

      // Transcribe untranscribed audio messages before AI generation
      const audioMessageIds = recentMessages
        .filter(msg =>
          (msg.attachments || []).some(
            a => a.file_type === 'audio' && !a.transcribed_text
          )
        )
        .map(msg => msg.id);

      if (audioMessageIds.length > 0) {
        try {
          const transcribeResponse = await JiraAPI.transcribeAudio(audioMessageIds);
          const transcriptions = transcribeResponse.data?.transcriptions || {};
          recentMessages.forEach(msg => {
            (msg.attachments || []).forEach(a => {
              if (a.file_type === 'audio' && !a.transcribed_text && transcriptions[a.id]) {
                a.transcribed_text = transcriptions[a.id];
              }
            });
          });
        } catch {
          // Continue without transcriptions if it fails
        }
      }

      messagesContent = recentMessages
        .map(msg => {
          const senderRole = getSenderLabel(msg);
          const attrs = msg.content_attributes || {};
          const name = attrs.wa_team_member_name || attrs.waTeamMemberName || msg.sender?.name || attrs.wa_sender_name || 'Unknown';
          let text = msg.content || '';
          const audioTranscriptions = (msg.attachments || [])
            .filter(a => a.file_type === 'audio' && a.transcribed_text)
            .map(a => `[Audio transcription: ${a.transcribed_text}]`);
          if (audioTranscriptions.length > 0) {
            text = text
              ? `${text}\n${audioTranscriptions.join('\n')}`
              : audioTranscriptions.join('\n');
          }
          return text ? `${name} (${senderRole}): ${text}` : '';
        })
        .filter(m => m.trim())
        .join('\n\n');
    }

    const response = await OpenaiAPI.enhanceTicket({
      title: '',
      description: '',
      messages: messagesContent,
      enhancementOptions: ['improve_title', 'improve_description', 'suggest_priority', 'suggest_issue_type', 'suggest_category'],
      availableCategories: availableCategories.value.map(c => c.name),
      availableIssueTypes: issueTypes.value.map(t => t.name),
      hookId: openaiHook.hooks[0].id,
    });

    let aiData = response.data;
    if (typeof aiData === 'string') {
      try { aiData = JSON.parse(aiData); } catch { aiData = { description: aiData }; }
    }
    if (aiData.message) {
      if (typeof aiData.message === 'string') {
        try { aiData = JSON.parse(aiData.message); } catch { aiData = { description: aiData.message }; }
      } else {
        aiData = aiData.message;
      }
    }

    if (aiData.title) formState.value.summary = aiData.title;
    if (aiData.description) formState.value.description = aiData.description;

    // Map AI-suggested priority to JIRA priority
    if (aiData.priority && priorities.value.length > 0) {
      const priorityMap = { urgent: 'highest', high: 'high', medium: 'medium', low: 'low' };
      const mapped = priorityMap[aiData.priority.toLowerCase()] || aiData.priority.toLowerCase();
      const match = priorities.value.find(
        p => p.name.toLowerCase() === mapped || p.name.toLowerCase().includes(mapped)
      );
      // Fallback: if 'highest' not found, try 'blocker'; if 'low' not found, try 'minor'
      const fallbacks = { highest: ['blocker'], low: ['minor', 'lowest'] };
      const resolved = match || (fallbacks[mapped] || []).reduce(
        (found, alt) => found || priorities.value.find(p => p.name.toLowerCase() === alt),
        null
      );
      if (resolved) formState.value.priority_id = resolved.id;
    }

    // Map AI-suggested issue type to JIRA issue type
    if (aiData.issue_type && issueTypes.value.length > 0) {
      const typeMatch = issueTypes.value.find(
        t => t.name.toLowerCase() === aiData.issue_type.toLowerCase()
          || t.name.toLowerCase().includes(aiData.issue_type.toLowerCase())
      );
      if (typeMatch) formState.value.issue_type_id = typeMatch.id;
    }

    // Map AI-suggested category (case-insensitive)
    if (aiData.category && availableCategories.value.length > 0) {
      const catMatch = availableCategories.value.find(
        c => c.name.toLowerCase() === aiData.category.toLowerCase()
          || c.name.toLowerCase().includes(aiData.category.toLowerCase())
      );
      if (catMatch) formState.value.category = catMatch.id;
    }

    useAlert('JIRA issue details generated with AI!');
  } catch (error) {
    const msg = error.response?.data?.error || error.message || 'AI generation failed';
    useAlert(msg);
  } finally {
    isGeneratingWithAI.value = false;
  }
};

onMounted(() => {
  getProjects();
});
</script>

<template>
  <div class="flex flex-col p-6 min-h-[400px]">
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
        :disabled="dropdown.disabled"
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

        <!-- Manually Attached Files -->
        <div v-if="attachments.length > 0" class="space-y-2">
          <div
            v-for="attachment in attachments"
            :key="attachment.id"
            class="flex items-center justify-between p-2 bg-slate-50 dark:bg-slate-700 rounded"
          >
            <div class="flex items-center gap-2">
              <fluent-icon icon="document" size="14" class="text-slate-500 dark:text-slate-400" />
              <span class="text-sm text-slate-900 dark:text-slate-100">{{ attachment.name }}</span>
              <span class="text-xs text-slate-500 dark:text-slate-400">({{ formatFileSize(attachment.size) }})</span>
            </div>
            <button
              type="button"
              class="text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 text-lg leading-none font-bold px-1"
              title="Remove"
              @click="removeAttachment(attachment.id)"
            >
              ×
            </button>
          </div>
        </div>

        <!-- Attachments from Selected Messages (same format as manual uploads) -->
        <div
          v-for="att in messageAttachments"
          :key="'msg-' + att.id"
          class="flex items-center justify-between p-2 bg-slate-50 dark:bg-slate-700 rounded"
        >
          <div class="flex items-center gap-2">
            <fluent-icon icon="document" size="14" class="text-slate-500 dark:text-slate-400" />
            <span class="text-sm text-slate-900 dark:text-slate-100 truncate">{{ getAttachmentName(att) }}</span>
            <span v-if="att.file_size" class="text-xs text-slate-500 dark:text-slate-400">({{ formatFileSize(att.file_size) }})</span>
          </div>
          <button
            type="button"
            class="text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 text-lg leading-none font-bold px-1"
            title="Remove"
            @click="removeMessageAttachment(att.id)"
          >
            ×
          </button>
        </div>
      </div>

      <!-- Generate with AI -->
      <Button
        faded
        blue
        size="small"
        icon="i-lucide-sparkles"
        label="Generate with AI"
        :loading="isGeneratingWithAI"
        :disabled="isCreating"
        class="w-full"
        @click="generateWithAI"
      />
    </div>

    <!-- Footer -->
    <div class="flex justify-end gap-3 pt-4 border-t border-slate-200 dark:border-slate-600">
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
