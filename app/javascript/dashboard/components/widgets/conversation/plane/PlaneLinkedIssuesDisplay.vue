<template>
  <div v-if="hasLinkedIssues" class="plane-linked-issues mb-3">
    <div class="flex flex-wrap gap-1.5">
      <woot-label
        v-for="issue in displayedIssues"
        :key="issue.id"
        :title="issue.sequence_id"
        :description="issue.name || ''"
        show-close
        color="var(--color-primary)"
        variant="smooth"
        class="max-w-[calc(100%-0.5rem)] cursor-pointer"
        @click="handlePlaneLabelClick(issue, $event)"
        @remove="unlinkIssue(issue)"
      >
        <template #default>
          <div class="flex items-center gap-1.5">
            <i class="i-lucide-layers text-xs opacity-70"></i>
            <span class="text-xs font-medium">{{ issue.sequence_id || issue.id.substring(0, 8) }}</span>
            <span class="text-xs opacity-75 truncate max-w-32">
              {{ issue.name || '' }}
            </span>
            <span 
              v-if="issue.state_name"
              class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium"
              :style="{ backgroundColor: getStateBackgroundColor(issue.state_name, issue.state_color), color: getStateTextColor(issue.state_name, issue.state_color) }"
            >
              {{ issue.state_name }}
            </span>
          </div>
        </template>
      </woot-label>

      <!-- Show "+n more" if there are more than 2 issues -->
      <button
        v-if="hasMoreIssues"
        type="button"
        class="inline-flex items-center px-2.5 py-1.5 text-xs font-medium text-purple-600 dark:text-purple-400 bg-purple-100 dark:bg-purple-900/50 hover:bg-purple-200 dark:hover:bg-purple-800/60 rounded-md transition-all duration-200 cursor-pointer border border-purple-300 dark:border-purple-700 hover:border-purple-400 dark:hover:border-purple-600 active:scale-95"
        @click.stop="showAllIssues"
      >
        <i class="i-lucide-chevron-down text-xs mr-0.5"></i>
        +{{ remainingCount }} {{ $t('INTEGRATION_SETTINGS.PLANE.MORE_ISSUES') }}
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
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PlaneAPI from 'dashboard/api/integrations/plane';
import { parsePlaneAPIErrorResponse } from './helpers/apiErrorHelper';
import { usePlaneIssues, getPlaneStateBgColor, getPlaneStateColor } from 'dashboard/composables/usePlaneIssues';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const showAll = ref(false);

// Single source of truth — shared with IssuesList/ConversationLabels
const { issues: linkedIssues, isLoading, refresh, removeIssue } = usePlaneIssues(
  computed(() => props.conversationId)
);

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

const getStateBackgroundColor = (stateName, stateColor) => {
  return getPlaneStateBgColor(stateName, stateColor);
};

const getStateTextColor = (stateName, stateColor) => {
  return getPlaneStateColor(stateName, stateColor);
};

const unlinkIssue = async (issue) => {
  try {
    await PlaneAPI.unlinkIssue(issue.project_id, issue.id, props.conversationId);
    removeIssue(issue.id);
    window.dispatchEvent(new CustomEvent('plane:issues-updated'));
    useAlert(t('INTEGRATION_SETTINGS.PLANE.UNLINK.SUCCESS'));
  } catch (error) {
    const errorMessage = parsePlaneAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.PLANE.UNLINK.ERROR')
    );
    useAlert(errorMessage);
  }
};

const openIssue = (issue) => {
  if (issue.url) {
    window.open(issue.url, '_blank');
  }
};

const handlePlaneLabelClick = (issue, event) => {
  const isCloseButton = event.target.closest('.label-close--button') || 
                       event.target.closest('.close--icon');
  if (!isCloseButton) {
    openIssue(issue);
  }
};

const showAllIssues = () => {
  showAll.value = true;
  const event = new CustomEvent('plane:open-all-issues', {
    detail: { conversationId: props.conversationId }
  });
  window.dispatchEvent(event);
};

const showLessIssues = () => {
  showAll.value = false;
};
</script>

<style scoped>
.plane-linked-issues {
  border-top: 1px solid var(--color-border);
  padding-top: 0.75rem;
  margin-top: 0.75rem;
  background-color: var(--color-background-light);
  border-radius: 0.5rem;
  padding: 1rem;
}
</style>
