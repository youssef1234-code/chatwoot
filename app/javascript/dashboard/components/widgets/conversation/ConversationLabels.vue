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
    
    <!-- JIRA issues as labels -->
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
    
    <!-- Show "+n more" button for JIRA issues -->
    <button
      v-if="hasMoreJiraIssues"
      type="button"
      class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900/50 hover:bg-blue-200 dark:hover:bg-blue-800/60 rounded-md transition-all duration-200 cursor-pointer border border-blue-300 dark:border-blue-700 hover:border-blue-400 dark:hover:border-blue-600"
      @click="toggleShowAllJiraIssues"
    >
      <i class="i-lucide-chevron-down text-xs mr-1"></i>
      +{{ remainingJiraCount }} more
    </button>

    <button
      v-if="showAllJiraIssues && jiraIssues.length > maxJiraLabels"
      type="button"
      class="inline-flex items-center px-2 py-1 text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-50/70 dark:bg-slate-800/30 hover:bg-slate-100 dark:hover:bg-slate-800/50 rounded-md transition-all duration-200 cursor-pointer border border-slate-200/60 dark:border-slate-700/60 hover:border-slate-300 dark:hover:border-slate-600"
      @click="toggleShowAllJiraIssues"
    >
      <i class="i-lucide-chevron-up text-xs mr-1"></i>
      Show less
    </button>

    <!-- Plane issues as labels -->
    <woot-label
      v-for="issue in displayedPlaneIssues"
      :key="`plane-${issue.key}`"
      :title="issue.key"
      :description="issue.name || issue.summary || ''"
      :color="getPlaneStateColor(issue.state_name, issue.state_color)"
      variant="smooth"
      size="small"
      show-close
      class="cursor-pointer plane-issue-label"
      @click="handlePlaneLabelClick(issue, $event)"
      @remove="unlinkPlaneIssue(issue)"
    >
      <template #default>
        <div class="flex items-center gap-1">
          <i class="i-lucide-layers text-xs opacity-70"></i>
          <span class="text-xs font-medium">{{ issue.key }}</span>
        </div>
      </template>
    </woot-label>

    <!-- Show "+n more" button for Plane issues -->
    <button
      v-if="hasMorePlaneIssues"
      type="button"
      class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900/50 hover:bg-blue-200 dark:hover:bg-blue-800/60 rounded-md transition-all duration-200 cursor-pointer border border-blue-300 dark:border-blue-700 hover:border-blue-400 dark:hover:border-blue-600"
      @click="toggleShowAllPlaneIssues"
    >
      <i class="i-lucide-chevron-down text-xs mr-1"></i>
      +{{ remainingPlaneCount }} more
    </button>

    <button
      v-if="showAllPlaneIssues && planeIssues.length > maxPlaneLabels"
      type="button"
      class="inline-flex items-center px-2 py-1 text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-50/70 dark:bg-slate-800/30 hover:bg-slate-100 dark:hover:bg-slate-800/50 rounded-md transition-all duration-200 cursor-pointer border border-slate-200/60 dark:border-slate-700/60 hover:border-slate-300 dark:hover:border-slate-600"
      @click="toggleShowAllPlaneIssues"
    >
      <i class="i-lucide-chevron-up text-xs mr-1"></i>
      Show less
    </button>
    
    <!-- Slot for custom content after labels -->
    <slot name="after" />
  </div>
</template>

<script setup>
import { computed, ref, onMounted, onUnmounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import JiraAPI from 'dashboard/api/integrations/jira';
import { loadStatusColors, getStatusHexColor } from './jira/helpers/statusColors';
import PlaneAPI from 'dashboard/api/integrations/plane';
import { parseJiraAPIErrorResponse } from './jira/helpers/apiErrorHelper';
import { emitter } from 'shared/helpers/mitt';
import { usePlaneIssues, getPlaneStateColor } from 'dashboard/composables/usePlaneIssues';

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
  maxPlaneLabels: {
    type: Number,
    default: 2,
  },
});

const emit = defineEmits(['labelClick']);

const accountLabels = useMapGetter('labels/getLabels');
const jiraIssues = ref([]);
const showAllJiraIssues = ref(false);
const showAllPlaneIssues = ref(false);
const maxJiraLabels = computed(() => props.maxJiraLabels);
const maxPlaneLabels = computed(() => props.maxPlaneLabels);

// Single source of truth for Plane issues — shared with IssuesList/PlaneLinkedIssuesDisplay
const { issues: planeIssues, removeIssue: removePlaneIssue } = usePlaneIssues(
  computed(() => props.conversation.id)
);

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

// Get status-based color for JIRA issues from shared config
const getJiraStatusColor = (status) => {
  return getStatusHexColor(status) || '#64748b';
};

const hasLabelsOrIssues = computed(() => {
  return conversationLabels.value.length > 0 || jiraIssues.value.length > 0 || planeIssues.value.length > 0;
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
    // Backend now returns { issues: [...], second_line_project_key: "..." }
    const payload = response.data || {};
    jiraIssues.value = payload.issues || payload || [];
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
  const issueIndex = jiraIssues.value.findIndex(issue => issue.key === data.issue_key);
  if (issueIndex !== -1) {
    jiraIssues.value[issueIndex] = {
      ...jiraIssues.value[issueIndex],
      status: data.issue_status || data.new_status,
      summary: data.issue_summary || jiraIssues.value[issueIndex].summary
    };
  }
};

const handleJiraCompletion = (data) => {
  const issueIndex = jiraIssues.value.findIndex(issue => issue.key === data.issue_key);
  if (issueIndex !== -1) {
    jiraIssues.value[issueIndex] = {
      ...jiraIssues.value[issueIndex],
      status: data.issue_status || data.new_status,
      summary: data.issue_summary || jiraIssues.value[issueIndex].summary
    };
  }
};

// ---- Plane issue methods ----
// Colors come from the centralized composable — no local map needed
const getPlaneStatusColor = (stateName) => getPlaneStateColor(stateName);

const hasMorePlaneIssues = computed(() => {
  return !showAllPlaneIssues.value && planeIssues.value.length > maxPlaneLabels.value;
});

const displayedPlaneIssues = computed(() => {
  return showAllPlaneIssues.value
    ? planeIssues.value
    : planeIssues.value.slice(0, maxPlaneLabels.value);
});

const remainingPlaneCount = computed(() => {
  return planeIssues.value.length - maxPlaneLabels.value;
});

const openPlaneIssue = (issue) => {
  if (issue.url) {
    window.open(issue.url, '_blank');
  }
};

const unlinkPlaneIssue = async (issue) => {
  try {
    await PlaneAPI.unlinkIssue(issue.project_id, issue.id, props.conversation.id);
    removePlaneIssue(issue.id);
    window.dispatchEvent(new CustomEvent('plane:issues-updated'));
    useAlert(t('INTEGRATION_SETTINGS.PLANE.UNLINK.SUCCESS'));
  } catch (error) {
    console.error('Failed to unlink Plane issue:', error);
    useAlert(t('INTEGRATION_SETTINGS.PLANE.UNLINK.ERROR'));
  }
};

const handlePlaneLabelClick = (issue, event) => {
  const isCloseButton = event.target.closest('.label-close--button') ||
                       event.target.closest('.close--icon');
  if (!isCloseButton) {
    openPlaneIssue(issue);
  }
};

const toggleShowAllPlaneIssues = () => {
  showAllPlaneIssues.value = !showAllPlaneIssues.value;
};

// Re-load JIRA issues when conversation changes (DynamicScroller recycles components)
watch(
  () => props.conversation.id,
  (newId, oldId) => {
    if (newId !== oldId) {
      jiraIssues.value = [];
      loadJiraIssues();
    }
  }
);

// Lifecycle — only JIRA needs manual event listeners (Plane is handled by usePlaneIssues)
onMounted(async () => {
  await loadStatusColors();
  loadJiraIssues();
  window.addEventListener('jira:issues-updated', handleJiraIssuesUpdated);
  emitter.on('jira:issue-status-updated', handleJiraStatusUpdate);
  emitter.on('jira:issue-completed', handleJiraCompletion);
});

onUnmounted(() => {
  window.removeEventListener('jira:issues-updated', handleJiraIssuesUpdated);
  emitter.off('jira:issue-status-updated', handleJiraStatusUpdate);
  emitter.off('jira:issue-completed', handleJiraCompletion);
});
</script>
