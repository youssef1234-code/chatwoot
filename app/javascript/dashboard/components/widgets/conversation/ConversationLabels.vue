<template>
  <div v-if="hasLabelsOrIssues" class="flex flex-wrap gap-1 mt-1">
    <!-- Slot for custom content before labels -->
    <slot name="before" />
    
    <!-- Regular conversation labels -->
    <woot-label
      v-for="label in conversationLabels"
      :key="label.id"
      :title="label.title"
      :description="label.description"
      :color="label.color"
      variant="smooth"
      size="small"
      class="cursor-pointer"
      @click="$emit('labelClick', label)"
    />
    
    <!-- JIRA issues as labels (displayed issues based on showAllJiraIssues state) -->
    <woot-label
      v-for="issue in displayedJiraIssues"
      :key="`jira-${issue.key}`"
      :title="issue.key"
      :description="issue.summary || issue.title || ''"
      :color="getJiraStatusColor(issue.status)"
      variant="smooth"
      size="small"
      show-close
      class="cursor-pointer jira-issue-label"
      @click="handleJiraLabelClick(issue, $event)"
      @remove="unlinkJiraIssue(issue)"
    >
      <template #default>
        <div class="flex items-center gap-1">
          <i class="i-lucide-external-link text-xs opacity-70"></i>
          <span class="text-xs font-medium">{{ issue.key }}</span>
        </div>
      </template>
    </woot-label>
    
    <!-- Show "+n more" button if there are more JIRA issues and not showing all -->
    <button
      v-if="hasMoreJiraIssues"
      type="button"
      class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900/50 hover:bg-blue-200 dark:hover:bg-blue-800/60 rounded-md transition-all duration-200 cursor-pointer border border-blue-300 dark:border-blue-700 hover:border-blue-400 dark:hover:border-blue-600"
      @click="toggleShowAllJiraIssues"
    >
      <i class="i-lucide-chevron-down text-xs mr-1"></i>
      +{{ remainingJiraCount }} more
    </button>

    <!-- Show "Show less" button if showing all issues and there are more than maxJiraLabels -->
    <button
      v-if="showAllJiraIssues && jiraIssues.length > maxJiraLabels"
      type="button"
      class="inline-flex items-center px-2 py-1 text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-50/70 dark:bg-slate-800/30 hover:bg-slate-100 dark:hover:bg-slate-800/50 rounded-md transition-all duration-200 cursor-pointer border border-slate-200/60 dark:border-slate-700/60 hover:border-slate-300 dark:hover:border-slate-600"
      @click="toggleShowAllJiraIssues"
    >
      <i class="i-lucide-chevron-up text-xs mr-1"></i>
      Show less
    </button>
    
    <!-- Slot for custom content after labels -->
    <slot name="after" />
  </div>
</template>

<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import JiraAPI from 'dashboard/api/integrations/jira';
import { parseJiraAPIErrorResponse } from './jira/helpers/apiErrorHelper';
import { emitter } from 'shared/helpers/mitt';

const { t } = useI18n();

const props = defineProps({
  conversation: {
    type: Object,
    required: true,
  },
  maxJiraLabels: {
    type: Number,
    default: 2,
  },
});

const emit = defineEmits(['labelClick']);

const accountLabels = useMapGetter('labels/getLabels');
const jiraIssues = ref([]);
const showAllJiraIssues = ref(false);
const maxJiraLabels = computed(() => props.maxJiraLabels);

// Get complete label objects from the store based on conversation label names
const conversationLabels = computed(() => {
  if (!props.conversation.labels || !accountLabels.value) return [];
  
  return accountLabels.value.filter(label => {
    // Match labels by title/name
    return props.conversation.labels.some(conversationLabel => {
      // Handle both string format and object format
      const labelName = typeof conversationLabel === 'string' 
        ? conversationLabel 
        : conversationLabel.title || conversationLabel.name;
      return label.title === labelName;
    });
  });
});

// Function to get status-based color for JIRA issues
const getJiraStatusColor = (status) => {
  if (!status) {
    console.log('JIRA ConversationLabels: getJiraStatusColor - no status, returning default blue');
    return '#0052CC'; // Default JIRA blue
  }
  
  const statusLower = status.toLowerCase();
  console.log('JIRA ConversationLabels: getJiraStatusColor called with status:', statusLower);
  
  const statusColors = {
    'to do': '#64748b',
    'todo': '#64748b',
    'open': '#64748b',
    'backlog': '#64748b',
    'in progress': '#2563eb',
    'in development': '#2563eb',
    'development': '#2563eb',
    'active': '#2563eb',
    'in review': '#d97706',
    'under review': '#d97706',
    'review': '#d97706',
    'testing': '#d97706',
    'qa': '#d97706',
    'done': '#16a34a',
    'closed': '#16a34a',
    'resolved': '#16a34a',
    'completed': '#16a34a',
    'waiting for support': '#dc2626',
    'waiting': '#dc2626',
    'blocked': '#dc2626',
    'on hold': '#dc2626'
  };
  
  // Try to find exact match first
  if (statusColors[statusLower]) {
    console.log(`JIRA ConversationLabels: Found exact match for '${statusLower}' -> ${statusColors[statusLower]}`);
    return statusColors[statusLower];
  }
  
  // Try partial matches
  for (const [key, color] of Object.entries(statusColors)) {
    if (statusLower.includes(key) || key.includes(statusLower)) {
      console.log(`JIRA ConversationLabels: Found partial match for '${statusLower}' with '${key}' -> ${color}`);
      return color;
    }
  }
  
  console.log(`JIRA ConversationLabels: No match found for '${statusLower}', returning default blue`);
  return '#0052CC'; // Default JIRA blue
};

const hasLabelsOrIssues = computed(() => {
  return conversationLabels.value.length > 0 || jiraIssues.value.length > 0;
});

const hasMoreJiraIssues = computed(() => {
  return !showAllJiraIssues.value && jiraIssues.value.length > maxJiraLabels.value;
});

const displayedJiraIssues = computed(() => {
  return showAllJiraIssues.value 
    ? jiraIssues.value 
    : jiraIssues.value.slice(0, maxJiraLabels.value);
});

const remainingJiraCount = computed(() => {
  return jiraIssues.value.length - maxJiraLabels.value;
});

const loadJiraIssues = async () => {
  try {
    const response = await JiraAPI.getLinkedIssues(props.conversation.id);
    jiraIssues.value = response.data || [];
  } catch (error) {
    // Silent fail - not critical for UX
    console.error('Failed to load JIRA issues for conversation labels:', error);
    jiraIssues.value = [];
  }
};

const openJiraIssue = (issue) => {
  if (issue.url) {
    window.open(issue.url, '_blank');
  }
};

const unlinkJiraIssue = async (issue) => {
  try {
    console.log('Unlinking JIRA issue:', issue);
    
    // Since we're using database-backed linking, we don't need to validate commentId anymore
    // Just pass a dummy value to maintain API compatibility
    const commentId = issue.commentId || issue.comment_id || 'database-link';
    
    await JiraAPI.unlinkIssue(issue.key, commentId, props.conversation.id);
    
    // Remove from local state
    jiraIssues.value = jiraIssues.value.filter(i => i.key !== issue.key);
    
    // Emit event for other components to update
    window.dispatchEvent(new CustomEvent('jira:issues-updated'));
    
    useAlert(t('INTEGRATION_SETTINGS.JIRA.UNLINK.SUCCESS'));
  } catch (error) {
    console.error('Failed to unlink JIRA issue:', error);
    const errorMessage = parseJiraAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.JIRA.UNLINK.ERROR')
    );
    useAlert(errorMessage);
  }
};

const handleJiraUnlink = (issue, event) => {
  // Stop the event from bubbling up to the wrapper div's click handler
  event.stopPropagation();
  unlinkJiraIssue(issue);
};

const handleJiraLabelClick = (issue, event) => {
  // Check if the click was on the close button or its child elements
  const isCloseButton = event.target.closest('.label-close--button') || 
                       event.target.closest('.close--icon');
  
  // If it's not the close button, open the JIRA issue
  if (!isCloseButton) {
    openJiraIssue(issue);
  }
};

const toggleShowAllJiraIssues = () => {
  showAllJiraIssues.value = !showAllJiraIssues.value;
};

const openAllJiraIssues = () => {
  // Emit event to open JIRA issues in sidebar or modal
  const event = new CustomEvent('jira:open-all-issues', {
    detail: { conversationId: props.conversation.id }
  });
  window.dispatchEvent(event);
};

const handleJiraIssuesUpdated = () => {
  loadJiraIssues();
};

// Handle real-time JIRA status updates
const handleJiraStatusUpdate = (data) => {
  console.log('JIRA ConversationLabels: Received status update', data);
  
  // Check if any of our JIRA issues match the updated issue
  const issueIndex = jiraIssues.value.findIndex(issue => issue.key === data.issue_key);
  
  if (issueIndex !== -1) {
    console.log('JIRA ConversationLabels: Updating issue status in conversation labels', {
      issueKey: data.issue_key,
      oldStatus: jiraIssues.value[issueIndex].status,
      newStatus: data.issue_status || data.new_status,
      conversationId: props.conversation.id
    });
    
    // Update the status of the specific issue
    jiraIssues.value[issueIndex] = {
      ...jiraIssues.value[issueIndex],
      status: data.issue_status || data.new_status,
      summary: data.issue_summary || jiraIssues.value[issueIndex].summary
    };
    
    console.log('JIRA ConversationLabels: Updated issue:', jiraIssues.value[issueIndex]);
  } else {
    console.log('JIRA ConversationLabels: Issue not found in current conversation labels', data.issue_key);
  }
};

const handleJiraCompletion = (data) => {
  console.log('JIRA ConversationLabels: Received completion event', data);
  
  // Find and update the completed issue (regardless of conversation ID since JIRA status is global)
  const issueIndex = jiraIssues.value.findIndex(issue => issue.key === data.issue_key);
  
  if (issueIndex !== -1) {
    console.log('JIRA ConversationLabels: Updating completed issue in conversation labels', {
      issueKey: data.issue_key,
      oldStatus: jiraIssues.value[issueIndex].status,
      newStatus: data.issue_status || data.new_status,
      conversationId: props.conversation.id,
      eventConversationId: data.conversation_id
    });
    
    jiraIssues.value[issueIndex] = {
      ...jiraIssues.value[issueIndex],
      status: data.issue_status || data.new_status,
      summary: data.issue_summary || jiraIssues.value[issueIndex].summary
    };
    
    console.log('JIRA ConversationLabels: Updated completed issue:', jiraIssues.value[issueIndex]);
  } else {
    console.log('JIRA ConversationLabels: Completed issue not found in current conversation labels', data.issue_key);
  }
};

onMounted(() => {
  loadJiraIssues();
  window.addEventListener('jira:issues-updated', handleJiraIssuesUpdated);
  // Listen for real-time JIRA status updates
  emitter.on('jira:issue-status-updated', handleJiraStatusUpdate);
  emitter.on('jira:issue-completed', handleJiraCompletion);
});

onUnmounted(() => {
  window.removeEventListener('jira:issues-updated', handleJiraIssuesUpdated);
  // Clean up real-time event listeners
  emitter.off('jira:issue-status-updated', handleJiraStatusUpdate);
  emitter.off('jira:issue-completed', handleJiraCompletion);
});
</script>
