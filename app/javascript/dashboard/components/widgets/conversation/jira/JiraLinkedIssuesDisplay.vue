<template>
  <div v-if="hasLinkedIssues" class="jira-linked-issues mb-3">
    <div class="flex flex-wrap gap-1.5">
      <woot-label
        v-for="issue in displayedIssues"
        :key="issue.key"
        :title="issue.key"
        :description="issue.summary || issue.title || ''"
        show-close
        color="#0052CC"
        variant="smooth"
        class="max-w-[calc(100%-0.5rem)] cursor-pointer"
        @click="openIssue(issue)"
        @remove="unlinkIssue(issue.key)"
      >
        <template #default>
          <div class="flex items-center gap-1.5">
            <i class="i-lucide-external-link text-xs opacity-70"></i>
            <span class="text-xs font-medium">{{ issue.key }}</span>
            <span class="text-xs opacity-75 truncate max-w-32">
              {{ issue.summary || issue.title || '' }}
            </span>
          </div>
        </template>
      </woot-label>

      <!-- Show "+n more" if there are more than 2 issues -->
      <button
        v-if="hasMoreIssues"
        type="button"
        class="inline-flex items-center px-2.5 py-1.5 text-xs font-medium text-blue-600 dark:text-blue-400 bg-blue-50/70 dark:bg-blue-900/30 hover:bg-blue-100 dark:hover:bg-blue-900/50 rounded-md transition-all duration-200 cursor-pointer border border-blue-200/60 dark:border-blue-700/60 hover:border-blue-300 dark:hover:border-blue-600 active:scale-95"
        @click.stop="showAllIssues"
      >
        <i class="i-lucide-chevron-down text-xs mr-0.5"></i>
        +{{ remainingCount }} {{ $t('INTEGRATION_SETTINGS.JIRA.MORE_ISSUES') }}
      </button>

      <!-- Show "Show less" if all issues are displayed and there are more than 2 -->
      <button
        v-if="showAll && linkedIssues.length > 2"
        type="button"
        class="inline-flex items-center px-2.5 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-50/70 dark:bg-slate-800/30 hover:bg-slate-100 dark:hover:bg-slate-800/50 rounded-md transition-all duration-200 cursor-pointer border border-slate-200/60 dark:border-slate-700/60 hover:border-slate-300 dark:hover:border-slate-600 active:scale-95"
        @click.stop="showLessIssues"
      >
        <i class="i-lucide-chevron-up text-xs mr-0.5"></i>
        Show less
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import JiraAPI from 'dashboard/api/integrations/jira';
import { parseJiraAPIErrorResponse } from './helpers/apiErrorHelper';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const linkedIssues = ref([]);
const isLoading = ref(false);
const showAll = ref(false);

const hasLinkedIssues = computed(() => {
  console.log('JiraLinkedIssuesDisplay - hasLinkedIssues computed:', linkedIssues.value.length > 0, linkedIssues.value);
  return linkedIssues.value.length > 0;
});

const displayedIssues = computed(() => {
  const result = showAll.value || linkedIssues.value.length <= 2 
    ? linkedIssues.value 
    : linkedIssues.value.slice(0, 2);
  console.log('JiraLinkedIssuesDisplay - displayedIssues computed:', result.length, 'showAll:', showAll.value);
  return result;
});

const hasMoreIssues = computed(() => {
  const result = !showAll.value && linkedIssues.value.length > 2;
  console.log('JiraLinkedIssuesDisplay - hasMoreIssues computed:', result, 'total issues:', linkedIssues.value.length);
  return result;
});

const remainingCount = computed(() => 
  linkedIssues.value.length - displayedIssues.value.length
);

const loadLinkedIssues = async () => {
  console.log('JiraLinkedIssuesDisplay - Loading linked issues for conversation:', props.conversationId);
  isLoading.value = true;
  try {
    const response = await JiraAPI.getLinkedIssues(props.conversationId);
    linkedIssues.value = response.data || [];
    console.log('JiraLinkedIssuesDisplay - Loaded linked issues:', linkedIssues.value);
  } catch (error) {
    console.error('Failed to load linked JIRA issues:', error);
    linkedIssues.value = [];
  } finally {
    isLoading.value = false;
  }
};

const unlinkIssue = async (issueKey) => {
  try {
    // Find the issue to get the comment ID
    const issue = linkedIssues.value.find(i => i.key === issueKey);
    if (!issue) return;

    await JiraAPI.unlinkIssue(issueKey, issue.commentId, props.conversationId);
    
    // Remove from local state
    linkedIssues.value = linkedIssues.value.filter(i => i.key !== issueKey);
    
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

const openIssue = (issue) => {
  if (issue.url) {
    window.open(issue.url, '_blank');
  }
};

const showAllIssues = () => {
  console.log('Showing all JIRA issues. Current count:', linkedIssues.value.length);
  showAll.value = true;
};

const showLessIssues = () => {
  console.log('Showing less JIRA issues');
  showAll.value = false;
};

// Listen for updates from other JIRA components
const handleJiraIssuesUpdated = () => {
  loadLinkedIssues();
};

onMounted(() => {
  console.log('JiraLinkedIssuesDisplay - Component mounted for conversation:', props.conversationId);
  loadLinkedIssues();
  window.addEventListener('jira:issues-updated', handleJiraIssuesUpdated);
});

onUnmounted(() => {
  console.log('JiraLinkedIssuesDisplay - Component unmounted');
  window.removeEventListener('jira:issues-updated', handleJiraIssuesUpdated);
});
</script>

<style scoped>
.jira-linked-issues {
  border-top: 1px solid var(--n-border);
  padding-top: 0.75rem;
  margin-top: 0.75rem;
}
</style>
