<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PlaneAPI from 'dashboard/api/integrations/plane';
import PlaneComments from './PlaneComments.vue';
import PlaneEditIssue from './PlaneEditIssue.vue';
import { getPlaneStateColor } from 'dashboard/composables/usePlaneIssues';

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
const showEdit = ref(false);
const issueDetails = ref(props.issue);

// Parent owns the data via usePlaneIssues composable.
// This component just mirrors props.issue into a local ref for display.
// No independent event listeners — parent array updates trigger this watcher.
watch(
  () => props.issue,
  (newIssue) => {
    if (newIssue) {
      issueDetails.value = { ...newIssue };
    }
  },
  { deep: true, immediate: true }
);

const issueId = computed(() => issueDetails.value.id);
const projectId = computed(() => issueDetails.value.project_id);
const issueKey = computed(() => issueDetails.value.key || `P-${issueDetails.value.sequence_id || '?'}`);
const issueName = computed(() => issueDetails.value.name || issueDetails.value.summary);
const issueState = computed(() => issueDetails.value.state_name || issueDetails.value.status || 'Backlog');
const issueStateColor = computed(() => getPlaneStateColor(issueState.value, issueDetails.value.state_color));
const issuePriority = computed(() => issueDetails.value.priority || 'none');
const issueAssignee = computed(() => {
  const assignees = issueDetails.value.assignees;
  if (assignees && assignees.length > 0) {
    // Handle both string and object formats
    if (typeof assignees[0] === 'string') return assignees[0];
    return assignees[0].display_name || 'Assigned';
  }
  return 'Unassigned';
});

const planeUrl = computed(() => {
  // Use URL from backend response (built with web_url setting)
  if (issueDetails.value.url) return issueDetails.value.url;
  // Fallback: construct from workspace_slug
  const workspaceSlug = issueDetails.value.workspace_slug || 'default';
  return `/${workspaceSlug}/projects/${projectId.value}/issues/${issueId.value}`;
});

const handleUnlink = () => {
  emit('unlink', projectId.value, issueId.value);
};

const openIssue = () => {
  window.open(planeUrl.value, '_blank');
};

const refreshIssue = async () => {
  isRefreshing.value = true;
  try {
    const response = await PlaneAPI.getIssue(projectId.value, issueId.value);
    if (response.data) {
      issueDetails.value = { ...issueDetails.value, ...response.data };
      emit('refresh');
      useAlert(t('INTEGRATION_SETTINGS.PLANE.ISSUE.ISSUE_REFRESHED'));
    }
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.ISSUE.REFRESH_ERROR'));
  } finally {
    isRefreshing.value = false;
  }
};

const onEditSaved = () => {
  showEdit.value = false;
  refreshIssue();
};

const getPriorityColor = (priority) => {
  const priorityColors = {
    'urgent': 'bg-red-600 text-white border-red-200',
    'high': 'bg-orange-600 text-white border-orange-200',
    'medium': 'bg-amber-600 text-white border-amber-200',
    'low': 'bg-blue-600 text-white border-blue-200',
    'none': 'bg-gray-600 text-white border-gray-200'
  };
  return priorityColors[priority?.toLowerCase()] || 'bg-gray-600 text-white border-gray-200';
};

const getPriorityLabel = (priority) => {
  const labels = {
    'urgent': 'Urgent',
    'high': 'High',
    'medium': 'Medium',
    'low': 'Low',
    'none': 'No Priority'
  };
  return labels[priority?.toLowerCase()] || 'No Priority';
};
</script>

<template>
  <div class="p-4 rounded-xl hover:bg-n-alpha-1 transition-all duration-200 shadow-sm hover:shadow-md border border-n-weak">
    <div class="flex items-start justify-between gap-4">
      <div class="flex-1 min-w-0">
        <!-- Issue header -->
        <div class="flex items-center gap-3 mb-3">
          <button
            class="inline-flex items-center gap-2 text-indigo-700 hover:text-indigo-800 font-semibold text-sm bg-indigo-50 hover:bg-indigo-100 px-3 py-1.5 rounded-lg transition-colors"
            @click="openIssue"
          >
            <div class="w-4 h-4 bg-indigo-600 rounded text-white text-xs flex items-center justify-center font-bold">
              P
            </div>
            {{ issueKey }}
            <i class="ri-external-link-line text-xs" />
          </button>
        </div>

        <!-- Issue title -->
        <h4 class="text-sm font-medium text-n-slate-12 mb-3 line-clamp-2 leading-relaxed">
          {{ issueName }}
        </h4>

        <!-- Issue metadata -->
        <div class="flex flex-wrap items-center gap-2 mb-4">
          <span
            class="px-3 py-1.5 rounded-full text-xs font-medium border shadow-sm text-white"
            :style="{ backgroundColor: issueStateColor }"
          >
            {{ issueState }}
          </span>
          <span
            class="px-3 py-1.5 rounded-full text-xs font-medium border shadow-sm"
            :class="getPriorityColor(issuePriority)"
          >
            {{ getPriorityLabel(issuePriority) }}
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
            class="hover:bg-indigo-50 hover:text-indigo-700"
            @click="refreshIssue"
          >
            <i class="ri-refresh-line" />
            {{ $t('INTEGRATION_SETTINGS.PLANE.ISSUE.REFRESH') }}
          </NextButton>

          <NextButton
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-indigo-50 hover:text-indigo-700"
            @click="showComments = true"
          >
            <i class="ri-chat-3-line" />
            {{ $t('INTEGRATION_SETTINGS.PLANE.COMMENTS.BUTTON') }}
          </NextButton>

          <NextButton
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-indigo-50 hover:text-indigo-700"
            @click="showEdit = true"
          >
            <i class="ri-edit-line" />
            {{ $t('INTEGRATION_SETTINGS.PLANE.EDIT.BUTTON') }}
          </NextButton>
          
          <NextButton
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-indigo-50 hover:text-indigo-700"
            @click="openIssue"
          >
            <i class="ri-external-link-line" />
            {{ $t('INTEGRATION_SETTINGS.PLANE.ISSUE.VIEW_IN_PLANE') }}
          </NextButton>
          
          <NextButton
            v-tooltip="$t('INTEGRATION_SETTINGS.PLANE.UNLINK.TITLE')"
            size="tiny"
            variant="ghost"
            color-scheme="alert"
            class="hover:bg-red-50 hover:text-red-700"
            @click="handleUnlink"
          >
            <i class="ri-link-unlink" />
            {{ $t('INTEGRATION_SETTINGS.PLANE.UNLINK.TITLE') }}
          </NextButton>
        </div>
      </div>
    </div>

    <!-- Comments Modal -->
    <PlaneComments
      v-if="showComments"
      :project-id="projectId"
      :issue-id="issueId"
      :issue-key="issueKey"
      @close="showComments = false"
    />

    <!-- Edit Issue Modal -->
    <PlaneEditIssue
      v-if="showEdit"
      :project-id="projectId"
      :issue-id="issueId"
      :issue-key="issueKey"
      :issue="issueDetails"
      @close="showEdit = false"
      @saved="onEditSaved"
    />
  </div>
</template>

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
