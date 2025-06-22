<script setup>
import { computed, ref, onMounted, onUnmounted, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import JiraAPI from 'dashboard/api/integrations/jira';
import JiraComments from './JiraComments.vue';
import { parseJiraAPIErrorResponse } from './helpers/apiErrorHelper';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  issue: {
    type: Object,
    required: true,
  },
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['unlink', 'refresh']);

const { t } = useI18n();
const isRefreshing = ref(false);
const showComments = ref(false);
const issueDetails = ref(props.issue);

// Listen for real-time JIRA updates
const handleJiraStatusUpdate = (data) => {
  console.log('JIRA JiraIssueItem: Received status update', data);
  console.log('JIRA JiraIssueItem: Current issue key:', issueKey.value);
  console.log('JIRA JiraIssueItem: Event issue key:', data.issue_key);
  console.log('JIRA JiraIssueItem: Current conversation ID:', props.conversationId);
  console.log('JIRA JiraIssueItem: Event conversation ID:', data.conversation_id);
  
  // Only update if this event is for this specific issue AND conversation
  if (data.issue_key === issueKey.value && data.conversation_id.toString() === props.conversationId.toString()) {
    console.log('JIRA JiraIssueItem: Updating issue status from', issueDetails.value.status, 'to', data.issue_status || data.new_status);
    
    // Update the issue status in real-time
    const newStatus = data.issue_status || data.new_status;
    issueDetails.value = {
      ...issueDetails.value,
      status: newStatus,
      summary: data.issue_summary || issueDetails.value.summary
    };
    console.log('JIRA JiraIssueItem: Updated issue details:', issueDetails.value);
    
    // Force reactivity update
    nextTick(() => {
      emit('refresh');
    });
  } else {
    console.log('JIRA JiraIssueItem: Ignoring status update for different issue/conversation');
  }
};

const handleJiraCompletion = (data) => {
  console.log('JIRA JiraIssueItem: Received completion event', data);
  // Only update if this event is for this specific issue AND conversation
  if (data.issue_key === issueKey.value && data.conversation_id.toString() === props.conversationId.toString()) {
    console.log('JIRA JiraIssueItem: Updating issue to completed status');
    
    // Update the issue to show it's completed
    const newStatus = data.issue_status || data.new_status;
    issueDetails.value = {
      ...issueDetails.value,
      status: newStatus,
      summary: data.issue_summary || issueDetails.value.summary
    };
    
    // Force reactivity update
    nextTick(() => {
      emit('refresh');
    });
    
    // Show completion notification
    useAlert(`🎉 JIRA Issue ${data.issue_key} has been completed!`);
  } else {
    console.log('JIRA JiraIssueItem: Ignoring completion event for different issue/conversation');
  }
};

onMounted(() => {
  emitter.on('jira:issue-status-updated', handleJiraStatusUpdate);
  emitter.on('jira:issue-completed', handleJiraCompletion);
});

onUnmounted(() => {
  emitter.off('jira:issue-status-updated', handleJiraStatusUpdate);
  emitter.off('jira:issue-completed', handleJiraCompletion);
});

// Watch for props changes and update local state
watch(
  () => props.issue,
  (newIssue) => {
    if (newIssue) {
      issueDetails.value = { ...newIssue };
    }
  },
  { deep: true, immediate: true }
);

const issueUrl = computed(() => issueDetails.value.url);
const issueKey = computed(() => issueDetails.value.key);
const issueSummary = computed(() => issueDetails.value.summary);
const issueStatus = computed(() => issueDetails.value.status);
const issueAssignee = computed(() => issueDetails.value.assignee || 'Unassigned');
const issuePriority = computed(() => issueDetails.value.priority || 'No Priority');
const issueType = computed(() => issueDetails.value.issueType);
const lastUpdated = computed(() => {
  if (issueDetails.value.updated) {
    return new Date(issueDetails.value.updated).toLocaleDateString();
  }
  return '';
});

const handleUnlink = () => {
  // Since we're using database-backed linking, we don't need to validate commentId anymore
  // Just pass a dummy value to maintain API compatibility
  const commentId = issueDetails.value.commentId || issueDetails.value.comment_id || 'database-link';
  
  emit('unlink', issueKey.value, commentId);
};

const openIssue = () => {
  window.open(issueUrl.value, '_blank');
};

const refreshIssue = async () => {
  isRefreshing.value = true;
  try {
    const response = await JiraAPI.getIssue(issueKey.value);
    if (response.data) {
      issueDetails.value = { ...issueDetails.value, ...response.data };
      emit('refresh');
      useAlert(t('INTEGRATION.JIRA.ISSUE_REFRESHED'));
    }
  } catch (error) {
    useAlert(t('INTEGRATION.JIRA.REFRESH_ERROR'));
  } finally {
    isRefreshing.value = false;
  }
};

const getPriorityColor = (priority) => {
  if (!priority || priority === 'No Priority') return 'bg-gray-600 text-white border-gray-200';
  
  const priorityColors = {
    'Highest': 'bg-red-600 text-white border-red-200 shadow-red-100',
    'Critical': 'bg-red-600 text-white border-red-200 shadow-red-100',
    'High': 'bg-orange-600 text-white border-orange-200 shadow-orange-100',
    'Medium': 'bg-amber-600 text-white border-amber-200 shadow-amber-100',
    'Low': 'bg-blue-600 text-white border-blue-200 shadow-blue-100',
    'Lowest': 'bg-slate-600 text-white border-slate-200 shadow-slate-100'
  };
  return priorityColors[priority] || 'bg-gray-600 text-white border-gray-200';
};

const getStatusColor = (status) => {
  if (!status) return 'bg-gray-600 text-white border-gray-300';
  
  const statusLower = status.toLowerCase();
  console.log('JIRA JiraIssueItem: getStatusColor called with status:', statusLower);
  const statusColors = {
    'to do': 'bg-slate-600 text-white border-slate-300',
    'todo': 'bg-slate-600 text-white border-slate-300',
    'open': 'bg-slate-600 text-white border-slate-300',
    'backlog': 'bg-slate-600 text-white border-slate-300',
    'in progress': 'bg-blue-600 text-black border-blue-300',
    'in development': 'bg-blue-600 text-white border-blue-300',
    'development': 'bg-blue-600 text-white border-blue-300',
    'active': 'bg-blue-600 text-white border-blue-300',
    'in review': 'bg-amber-600 text-white border-amber-300',
    'under review': 'bg-amber-600 text-white border-amber-300',
    'review': 'bg-amber-600 text-white border-amber-300',
    'testing': 'bg-amber-600 text-white border-amber-300',
    'qa': 'bg-amber-600 text-white border-amber-300',
    'done': 'bg-green-600 text-white border-green-300',
    'closed': 'bg-green-600 text-white border-green-300',
    'resolved': 'bg-green-600 text-white border-green-300',
    'completed': 'bg-green-600 text-white border-green-300',
    'waiting for support': 'bg-red-600 text-white border-red-300',
    'waiting': 'bg-red-600 text-white border-red-300',
    'blocked': 'bg-red-600 text-white border-red-300',
    'on hold': 'bg-red-600 text-white border-red-300'
  };
  
  // Try to find exact match first
  if (statusColors[statusLower]) {
    return statusColors[statusLower];
  }
  
  // Try partial matches
  for (const [key, color] of Object.entries(statusColors)) {
    if (statusLower.includes(key) || key.includes(statusLower)) {
      return color;
    }
  }
  
  return 'bg-gray-500 text-white border-gray-300';
};
</script>

<template>
  <div class="p-4 rounded-xl hover:bg-n-alpha-1 transition-all duration-200 shadow-sm hover:shadow-md border border-n-weak">
    <div class="flex items-start justify-between gap-4">
      <div class="flex-1 min-w-0">
        <!-- Issue header -->
        <div class="flex items-center gap-3 mb-3">
          <button
            class="inline-flex items-center gap-2 text-blue-700 hover:text-blue-800 font-semibold text-sm bg-blue-50 hover:bg-blue-100 px-3 py-1.5 rounded-lg transition-colors"
            @click="openIssue"
          >
            <div class="w-4 h-4 bg-blue-600 rounded text-black text-xs flex items-center justify-center font-bold">
              J
            </div>
            {{ issueKey }}
            <i class="ri-external-link-line text-xs" />
          </button>
          
          <span class="px-2 py-1 bg-n-alpha-1 text-n-slate-12 text-xs rounded-md font-medium">
            {{ issueType }}
          </span>
          
          <span v-if="lastUpdated" class="text-xs text-n-slate-10 hidden sm:block">
            {{ $t('INTEGRATION.JIRA.UPDATED') }}: {{ lastUpdated }}
          </span>
        </div>

        <!-- Issue title -->
        <h4 class="text-sm font-medium text-n-slate-12 mb-3 line-clamp-2 leading-relaxed">
          {{ issueSummary }}
        </h4>

        <!-- Issue metadata -->
        <div class="flex flex-wrap items-center gap-2 mb-4">
          <span
            class="px-3 py-1.5 rounded-full text-xs font-medium border shadow-sm"
            :class="getStatusColor(issueStatus)"
          >
            {{ issueStatus }}
          </span>
          <span
            class="px-3 py-1.5 rounded-full text-xs font-medium border shadow-sm"
            :class="getPriorityColor(issuePriority)"
          >
            {{ issuePriority }}
          </span>
          <div class="flex items-center text-xs text-n-slate-10 bg-n-alpha-1 px-2 py-1 rounded-md">
            <i class="ri-user-line mr-1" />
            {{ issueAssignee }}
          </div>
        </div>

        <!-- Action buttons -->
        <div class="flex items-center gap-2 flex-wrap">
          <NextButton
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            :is-loading="isRefreshing"
            class="hover:bg-blue-50 hover:text-blue-700"
            @click="refreshIssue"
          >
            <i class="ri-refresh-line" />
            {{ $t('INTEGRATION.JIRA.REFRESH') }}
          </NextButton>
          
          <NextButton
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-green-50 hover:text-green-700"
            @click="showComments = true"
          >
            <i class="ri-chat-1-line" />
            {{ $t('INTEGRATION.JIRA.COMMENTS.TITLE') }}
          </NextButton>
          
          <NextButton
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-indigo-50 hover:text-indigo-700"
            @click="openIssue"
          >
            <i class="ri-external-link-line" />
            {{ $t('INTEGRATION.JIRA.VIEW_IN_JIRA') }}
          </NextButton>
          
          <NextButton
            v-tooltip="$t('INTEGRATION.JIRA.UNLINK.TITLE')"
            size="tiny"
            variant="ghost"
            color-scheme="alert"
            class="hover:bg-red-50 hover:text-red-700"
            @click="handleUnlink"
          >
            <i class="ri-link-unlink" />
            {{ $t('INTEGRATION.JIRA.UNLINK.TITLE') }}
          </NextButton>
        </div>
      </div>
    </div>
  </div>

  <!-- Comments Modal -->
  <JiraComments
    v-if="showComments"
    :issue-key="issueKey"
    @close="showComments = false"
  />
</template>

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
