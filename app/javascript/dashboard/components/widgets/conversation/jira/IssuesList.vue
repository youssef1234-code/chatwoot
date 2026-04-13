<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import JiraAPI from 'dashboard/api/integrations/jira';
import Spinner from 'shared/components/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import JiraIssueItem from './JiraIssueItem.vue';
import CreateOrLinkIssue from './CreateOrLinkIssue.vue';
import { parseJiraAPIErrorResponse } from './helpers/apiErrorHelper';
import { emitter } from 'shared/helpers/mitt';

// Define JIRA tracking events (similar to Linear)
const JIRA_EVENTS = {
  CREATE_ISSUE: 'Created Jira Issue',
  LINK_ISSUE: 'Linked Jira Issue',
  UNLINK_ISSUE: 'Unlinked Jira Issue',
};

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const isLoading = ref(false);
const linkedIssues = ref([]);
const secondLineProjectKey = ref('');
const shouldShowCreateModal = ref(false);

const hasIssues = computed(() => linkedIssues.value.length > 0);

const loadLinkedIssues = async (isInitialLoad = false) => {
  if (isInitialLoad) {
    isLoading.value = true;
    linkedIssues.value = [];
  }
  try {
    const response = await JiraAPI.getLinkedIssues(props.conversationId);
    const payload = response.data || {};
    linkedIssues.value = payload.issues || payload || [];
    secondLineProjectKey.value = payload.second_line_project_key || '';
  } catch (error) {
    // Silent fail - not critical for UX
    console.error('Failed to load linked JIRA issues:', error);
  } finally {
    isLoading.value = false;
  }
};

const unlinkIssue = async (issueKey, commentId) => {
  try {
    await JiraAPI.unlinkIssue(issueKey, commentId, props.conversationId);
    useTrack(JIRA_EVENTS.UNLINK_ISSUE);
    linkedIssues.value = linkedIssues.value.filter(
      issue => issue.key !== issueKey
    );
    
    // Emit event for other components to update
    window.dispatchEvent(new CustomEvent('jira:issues-updated'));
    
    useAlert(t('INTEGRATION_SETTINGS.JIRA.UNLINK.SUCCESS'));
  } catch (error) {
    const errorMessage = parseJiraAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.JIRA.UNLINK.ERROR')
    );
    useAlert(errorMessage);
  }
};

const openCreateModal = () => {
  shouldShowCreateModal.value = true;
};

const closeCreateModal = () => {
  shouldShowCreateModal.value = false;
};

// Event listener for opening create modal from header button
const handleJiraCreateLink = (event) => {
  if (event.detail && event.detail.conversationId.toString() === props.conversationId.toString()) {
    openCreateModal();
  }
};

// Listen for link/unlink/create events from other components
const handleJiraIssuesUpdated = () => {
  loadLinkedIssues(false);
};

// Listen for real-time JIRA updates
const handleJiraStatusUpdate = (data) => {
  const hasIssueInCurrentConversation = linkedIssues.value.some(issue => issue.key === data.issue_key);
  
  if (data.conversation_id.toString() === props.conversationId.toString() || hasIssueInCurrentConversation) {
    setTimeout(() => {
      loadLinkedIssues(false);
    }, 100);
  }
};

const handleJiraCompletion = (data) => {
  if (data.conversation_id.toString() === props.conversationId.toString()) {
    setTimeout(() => {
      loadLinkedIssues(false);
    }, 100);
  }
};

watch(
  () => props.conversationId,
  () => {
    loadLinkedIssues(true);
  }
);

onMounted(() => {
  loadLinkedIssues(true);
  window.addEventListener('jira:open-create-link', handleJiraCreateLink);
  window.addEventListener('jira:issues-updated', handleJiraIssuesUpdated);
  emitter.on('jira:issue-status-updated', handleJiraStatusUpdate);
  emitter.on('jira:issue-completed', handleJiraCompletion);
});

onUnmounted(() => {
  window.removeEventListener('jira:open-create-link', handleJiraCreateLink);
  window.removeEventListener('jira:issues-updated', handleJiraIssuesUpdated);
  emitter.off('jira:issue-status-updated', handleJiraStatusUpdate);
  emitter.off('jira:issue-completed', handleJiraCompletion);
});
</script>

<template>
  <div>
    <div class="px-4 pt-3 pb-2">
      <NextButton
        ghost
        xs
        icon="i-lucide-plus"
        :label="$t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK_BUTTON')"
        @click="openCreateModal"
      />
    </div>

    <div v-if="isLoading" class="flex justify-center p-8">
      <Spinner />
    </div>

    <div v-else-if="!hasIssues" class="flex justify-center p-4">
      <p class="text-sm text-n-slate-11">
        {{ $t('INTEGRATION_SETTINGS.JIRA.NO_LINKED_ISSUES') }}
      </p>
    </div>

    <div v-else class="space-y-2 px-4 pb-4">
      <JiraIssueItem
        v-for="issue in linkedIssues"
        :key="issue.key"
        :issue="issue"
        :conversation-id="props.conversationId"
        :second-line-project-key="secondLineProjectKey"
        @unlink="unlinkIssue"
        @refresh="loadLinkedIssues"
      />
    </div>

    <CreateOrLinkIssue
      v-if="shouldShowCreateModal"
      :conversation-id="props.conversationId"
      @close="closeCreateModal"
    />
  </div>
</template>
