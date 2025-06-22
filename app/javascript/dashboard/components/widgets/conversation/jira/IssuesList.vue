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
const shouldShowCreateModal = ref(false);

const hasIssues = computed(() => linkedIssues.value.length > 0);

const loadLinkedIssues = async () => {
  isLoading.value = true;
  linkedIssues.value = [];
  try {
    const response = await JiraAPI.getLinkedIssues(props.conversationId);
    linkedIssues.value = response.data || [];
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
  loadLinkedIssues();
  
  // Emit event for other components to update
  window.dispatchEvent(new CustomEvent('jira:issues-updated'));
};

// Event listener for opening create modal from header button
const handleJiraCreateLink = (event) => {
  console.log('JIRA IssuesList: Received jira:open-create-link event', {
    eventDetail: event.detail,
    currentConversationId: props.conversationId,
    matches: event.detail && event.detail.conversationId.toString() === props.conversationId.toString()
  });
  
  if (event.detail && event.detail.conversationId.toString() === props.conversationId.toString()) {
    console.log('JIRA IssuesList: Opening create modal for conversation', props.conversationId);
    openCreateModal();
  } else {
    console.log('JIRA IssuesList: Ignoring event for different conversation');
  }
};

// Listen for real-time JIRA updates
const handleJiraStatusUpdate = (data) => {
  console.log('JIRA IssuesList: Received status update', data);
  console.log('JIRA IssuesList: Current conversation ID:', props.conversationId);
  console.log('JIRA IssuesList: Event conversation ID:', data.conversation_id);
  console.log('JIRA IssuesList: IDs match?', data.conversation_id.toString() === props.conversationId.toString());
  
  // Only update if this event is specifically for the current conversation
  if (data.conversation_id.toString() === props.conversationId.toString()) {
    console.log('JIRA IssuesList: Refreshing issues for conversation', props.conversationId);
    // Small delay to ensure backend updates are complete before fetching
    setTimeout(() => {
      loadLinkedIssues();
    }, 100);
  } else {
    console.log('JIRA IssuesList: Ignoring event for different conversation');
  }
};

const handleJiraCompletion = (data) => {
  console.log('JIRA IssuesList: Received completion event', data);
  // Only update if this event is specifically for the current conversation
  if (data.conversation_id.toString() === props.conversationId.toString()) {
    console.log('JIRA IssuesList: Refreshing issues for completed issue');
    // Small delay to ensure backend updates are complete before fetching
    setTimeout(() => {
      loadLinkedIssues();
    }, 100);
  } else {
    console.log('JIRA IssuesList: Ignoring completion event for different conversation');
  }
};

watch(
  () => props.conversationId,
  () => {
    loadLinkedIssues();
  }
);

onMounted(() => {
  console.log('JIRA IssuesList: Component mounted for conversation', props.conversationId);
  loadLinkedIssues();
  window.addEventListener('jira:open-create-link', handleJiraCreateLink);
  emitter.on('jira:issue-status-updated', handleJiraStatusUpdate);
  emitter.on('jira:issue-completed', handleJiraCompletion);
  console.log('JIRA IssuesList: Event listeners registered');
});

onUnmounted(() => {
  window.removeEventListener('jira:open-create-link', handleJiraCreateLink);
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
