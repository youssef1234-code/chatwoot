<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import { useStore } from 'vuex';
import JiraAPI from 'dashboard/api/integrations/jira';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { parseJiraAPIErrorResponse } from './helpers/apiErrorHelper';

const JIRA_EVENTS = {
  LINK_ISSUE: 'Linked Jira Issue',
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
  selectedMessageIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'issue-linked']);

const { t } = useI18n();
const store = useStore();

const currentChat = computed(() => store.getters.getSelectedChat);
const excludedMessageAttachmentIds = ref(new Set());

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
  if (!bytes || bytes === 0) return '';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

const issues = ref([]);
const selectedOption = ref({});
const shouldShowDropdown = ref(false);
const isFetching = ref(false);
const isLinking = ref(false);
const searchQuery = ref('');

const toggleDropdown = () => {
  issues.value = [];
  shouldShowDropdown.value = !shouldShowDropdown.value;
};

const linkIssueTitle = computed(() => {
  return selectedOption.value.id
    ? selectedOption.value.name
    : t('INTEGRATION_SETTINGS.JIRA.LINK.SELECT');
});

const isSubmitDisabled = computed(() => {
  return !selectedOption.value.id || isLinking.value;
});

const onSelectIssue = item => {
  selectedOption.value = item;
  toggleDropdown();
};

const onClose = () => {
  emit('close');
};

const onSearch = async (value) => {
  issues.value = [];
  if (!value) return;
  
  try {
    isFetching.value = true;
    const response = await JiraAPI.searchIssues(value);
    issues.value = response.data.map(issue => ({
      id: issue.key,
      name: `${issue.key} ${issue.summary}`,
      icon: 'status',
      iconColor: getStatusColor(issue.status),
      key: issue.key,
      summary: issue.summary,
      status: issue.status,
      issueType: issue.issueType
    }));
  } catch (error) {
    const errorMessage = parseJiraAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.JIRA.LINK.ERROR')
    );
    useAlert(errorMessage);
  } finally {
    isFetching.value = false;
  }
};

const linkIssue = async () => {
  const { key: issueKey } = selectedOption.value;
  try {
    isLinking.value = true;
    await JiraAPI.linkIssue(props.conversationId, issueKey, props.title, props.selectedMessageIds);

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

    useAlert(t('INTEGRATION_SETTINGS.JIRA.LINK.LINK_SUCCESS'));
    
    // Emit event for escalation workflow
    emit('issue-linked', {
      key: issueKey,
      summary: selectedOption.value.name,
      ...selectedOption.value
    });
    
    // Emit event for other components to update
    window.dispatchEvent(new CustomEvent('jira:issues-updated'));
    
    searchQuery.value = '';
    issues.value = [];
    onClose();
    useTrack(JIRA_EVENTS.LINK_ISSUE);
  } catch (error) {
    const errorMessage = parseJiraAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.JIRA.LINK.LINK_ERROR')
    );
    useAlert(errorMessage);
  } finally {
    isLinking.value = false;
  }
};

const getStatusColor = (status) => {
  const statusColors = {
    'To Do': '#6B7280',
    'In Progress': '#3B82F6',
    'Done': '#10B981',
    'Closed': '#059669'
  };
  return statusColors[status] || '#6B7280';
};
</script>

<template>
  <div class="flex flex-col h-full">
    <div class="flex-1 p-6">
      <p class="text-sm text-n-slate-11 mb-4">
        {{ $t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.DESCRIPTION') }}
      </p>

      <div
        class="flex flex-col border border-n-weak rounded-xl transition-all duration-200"
        :class="shouldShowDropdown ? 'h-[256px]' : 'gap-2'"
      >
        <Button
          variant="outline"
          class="justify-between w-full h-[2.5rem] py-1.5 px-3 rounded-xl"
          @click="toggleDropdown"
        >
          {{ linkIssueTitle }}
          <i class="i-lucide-chevron-down"></i>
        </Button>
        
        <div v-if="shouldShowDropdown" class="border-t border-n-weak">
          <Input
            v-model="searchQuery"
            :placeholder="$t('INTEGRATION_SETTINGS.JIRA.LINK.SEARCH')"
            class="m-2"
            @update:modelValue="onSearch"
          />
          <div class="max-h-48 overflow-y-auto p-2">
            <div v-if="isFetching" class="p-2 text-sm text-slate-600 dark:text-slate-400">
              {{ $t('INTEGRATION_SETTINGS.JIRA.LINK.LOADING') }}
            </div>
            <div
              v-for="issue in issues"
              :key="issue.id"
              class="p-2 cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700 rounded"
              :class="{ 'bg-slate-100 dark:bg-slate-700': selectedOption.id === issue.id }"
              @click="onSelectIssue(issue)"
            >
              <div class="font-medium text-slate-900 dark:text-slate-100">{{ issue.key }}</div>
              <div class="text-sm text-slate-600 dark:text-slate-400">{{ issue.summary }}</div>
            </div>
            <div v-if="issues.length === 0 && searchQuery && !isFetching" class="p-2 text-sm text-slate-600 dark:text-slate-400">
              {{ $t('INTEGRATION_SETTINGS.JIRA.LINK.EMPTY_LIST') }}
            </div>
          </div>
        </div>
      </div>

      <div v-if="!shouldShowDropdown && !selectedOption.id" class="mt-2">
        <p class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('INTEGRATION_SETTINGS.JIRA.LINK.EMPTY_LIST') }}
        </p>
      </div>

      <!-- Attachments from Selected Messages (same format as manual uploads) -->
      <div v-if="messageAttachments.length > 0" class="mt-4 space-y-2">
        <label class="block text-sm font-medium text-n-slate-12">
          <i class="ri-attachment-line mr-1" />
          Attachments ({{ messageAttachments.length }})
        </label>
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
    </div>

    <!-- Footer -->
    <div class="flex justify-end gap-3 p-6 pt-4 border-t border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800">
      <Button ghost slate :label="$t('INTEGRATION_SETTINGS.JIRA.CANCEL')" @click="onClose" />
      <Button
        blue
        :label="$t('INTEGRATION_SETTINGS.JIRA.LINK.TITLE')"
        :loading="isLinking"
        :disabled="isSubmitDisabled"
        @click="linkIssue"
      />
    </div>
  </div>
</template>
