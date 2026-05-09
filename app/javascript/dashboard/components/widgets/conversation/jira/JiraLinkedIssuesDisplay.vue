<template>
  <div v-if="hasLinkedIssues" class="jira-linked-issues mb-3">
    <div class="flex flex-wrap gap-1.5">
      <woot-label
        v-for="issue in displayedIssues"
        :key="issue.key"
        :title="issue.key"
        :description="issue.summary || issue.title || ''"
        show-close
        :bg-color="getIssueColor(issue)"
        class="max-w-[calc(100%-0.5rem)] cursor-pointer"
        @click="handleJiraLabelClick(issue, $event)"
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
        class="inline-flex items-center px-2.5 py-1.5 text-xs font-medium text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900/50 hover:bg-blue-200 dark:hover:bg-blue-800/60 rounded-md transition-all duration-200 cursor-pointer border border-blue-300 dark:border-blue-700 hover:border-blue-400 dark:hover:border-blue-600 active:scale-95"
        @click.stop="showAllIssues"
      >
        <i class="i-lucide-chevron-down text-xs mr-0.5"></i>
        +{{ remainingCount }} {{ $t('INTEGRATION_SETTINGS.JIRA.MORE_ISSUES') }}
      </button>

      <!-- Show "Show less" if all issues are displayed and there are more than 2 -->
      <button
        v-if="showAll && linkedIssues.length > 2"
        type="button"
        class="inline-flex items-center px-2.5 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-100 dark:bg-slate-800/50 hover:bg-slate-200 dark:hover:bg-slate-700/60 rounded-md transition-all duration-200 cursor-pointer border border-slate-300 dark:border-slate-700 hover:border-slate-400 dark:hover:border-slate-600 active:scale-95"
        @click.stop="showLessIssues"
      >
        <i class="i-lucide-chevron-up text-xs mr-0.5"></i>
        Show less
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import JiraAPI from 'dashboard/api/integrations/jira';
import { parseJiraAPIErrorResponse } from './helpers/apiErrorHelper';
import { loadStatusColors, getStatusHexColor } from './helpers/statusColors';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const getIssueColor = (issue) => {
  const status = issue.status;
  if (!status) return '#64748b';
  return getStatusHexColor(status) || '#64748b';
};

const { t } = useI18n();
const linkedIssues = ref([]);
const isLoading = ref(false);
const showAll = ref(false);

const hasLinkedIssues = computed(() => {
  return linkedIssues.value.length > 0;
});

const displayedIssues = computed(() => {
  return showAll.value || linkedIssues.value.length <= 2 
    ? linkedIssues.value 
    : linkedIssues.value.slice(0, 2);
});

const hasMoreIssues = computed(() => {
  return !showAll.value && linkedIssues.value.length > 2;
});

const remainingCount = computed(() => 
  linkedIssues.value.length - displayedIssues.value.length
);

const loadLinkedIssues = async (isInitialLoad = false) => {
  if (isInitialLoad) isLoading.value = true;
  try {
    const response = await JiraAPI.getLinkedIssues(props.conversationId);
    const payload = response.data || {};
    linkedIssues.value = payload.issues || payload || [];
  } catch (error) {
    console.error('Failed to load linked JIRA issues:', error);
    if (isInitialLoad) linkedIssues.value = [];
  } finally {
    isLoading.value = false;
  }
};

const unlinkIssue = async (issueKey) => {
  try {
    // Since we're using database-backed linking, we don't need a real commentId
    const commentId = 'database-link';

    await JiraAPI.unlinkIssue(issueKey, commentId, props.conversationId);
    
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

const handleJiraLabelClick = (issue, event) => {
  // Check if the click was on the close button or its child elements
  const isCloseButton = event.target.closest('.label-close--button') || 
                       event.target.closest('.close--icon');
  
  // If it's not the close button, open the JIRA issue
  if (!isCloseButton) {
    openIssue(issue);
  }
};

const showAllIssues = () => {
  showAll.value = true;
  
  // Emit event to open full view in JIRA sidebar or modal
  const event = new CustomEvent('jira:open-all-issues', {
    detail: { conversationId: props.conversationId }
  });
  window.dispatchEvent(event);
};

const showLessIssues = () => {
  showAll.value = false;
};

// Re-load when conversation changes (sidebar switches)
watch(
  () => props.conversationId,
  (newId, oldId) => {
    if (newId !== oldId) {
      linkedIssues.value = [];
      showAll.value = false;
      loadLinkedIssues(true);
    }
  }
);

// Listen for updates from other JIRA components
const handleJiraIssuesUpdated = () => {
  loadLinkedIssues();
};

onMounted(async () => {
  await loadStatusColors();
  loadLinkedIssues(true);
  window.addEventListener('jira:issues-updated', handleJiraIssuesUpdated);
});

onUnmounted(() => {
  window.removeEventListener('jira:issues-updated', handleJiraIssuesUpdated);
});
</script>

<style scoped>
.jira-linked-issues {
  border-top: 1px solid var(--color-border);
  padding-top: 0.75rem;
  margin-top: 0.75rem;
  background-color: var(--color-background-light);
  border-radius: 0.5rem;
  padding: 1rem;
}
</style>
