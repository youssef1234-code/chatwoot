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

const PAGE_SIZE = 5;

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const isLoading = ref(false);
const isRefreshing = ref(false);
const linkedIssues = ref([]);
const secondLineProjectKey = ref('');
const shouldShowCreateModal = ref(false);

// Tab + pagination state (independent per tab). Default to the 2nd line tab.
const activeTab = ref('second');
const firstLinePage = ref(1);
const secondLinePage = ref(1);

const isSecondLineIssue = issue => {
  if (!secondLineProjectKey.value || !issue.key) return false;
  return issue.key.split('-')[0] === secondLineProjectKey.value;
};

const firstLineIssues = computed(() =>
  linkedIssues.value.filter(issue => !isSecondLineIssue(issue))
);
const secondLineIssues = computed(() =>
  linkedIssues.value.filter(issue => isSecondLineIssue(issue))
);

const currentIssues = computed(() =>
  activeTab.value === 'first' ? firstLineIssues.value : secondLineIssues.value
);
const currentPage = computed(() =>
  activeTab.value === 'first' ? firstLinePage.value : secondLinePage.value
);
const totalPages = computed(() =>
  Math.max(1, Math.ceil(currentIssues.value.length / PAGE_SIZE))
);
const paginatedIssues = computed(() => {
  const start = (currentPage.value - 1) * PAGE_SIZE;
  return currentIssues.value.slice(start, start + PAGE_SIZE);
});

const setTab = tab => {
  activeTab.value = tab;
};

const setPage = page => {
  const clamped = Math.min(Math.max(1, page), totalPages.value);
  if (activeTab.value === 'first') {
    firstLinePage.value = clamped;
  } else {
    secondLinePage.value = clamped;
  }
};
const nextPage = () => setPage(currentPage.value + 1);
const prevPage = () => setPage(currentPage.value - 1);

// Keep the page within range when a tab's list shrinks (e.g. after unlink)
watch(firstLineIssues, () => {
  const max = Math.max(1, Math.ceil(firstLineIssues.value.length / PAGE_SIZE));
  if (firstLinePage.value > max) firstLinePage.value = max;
});
watch(secondLineIssues, () => {
  const max = Math.max(1, Math.ceil(secondLineIssues.value.length / PAGE_SIZE));
  if (secondLinePage.value > max) secondLinePage.value = max;
});

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

const refresh = async () => {
  if (isRefreshing.value) return;
  isRefreshing.value = true;
  try {
    await loadLinkedIssues(false);
  } finally {
    isRefreshing.value = false;
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
const handleJiraCreateLink = event => {
  if (
    event.detail &&
    event.detail.conversationId.toString() === props.conversationId.toString()
  ) {
    openCreateModal();
  }
};

// Listen for link/unlink/create events from other components
const handleJiraIssuesUpdated = () => {
  loadLinkedIssues(false);
};

// Listen for real-time JIRA updates
const handleJiraStatusUpdate = data => {
  const hasIssueInCurrentConversation = linkedIssues.value.some(
    issue => issue.key === data.issue_key
  );

  if (
    data.conversation_id.toString() === props.conversationId.toString() ||
    hasIssueInCurrentConversation
  ) {
    setTimeout(() => {
      loadLinkedIssues(false);
    }, 100);
  }
};

const handleJiraCompletion = data => {
  if (data.conversation_id.toString() === props.conversationId.toString()) {
    setTimeout(() => {
      loadLinkedIssues(false);
    }, 100);
  }
};

watch(
  () => props.conversationId,
  () => {
    firstLinePage.value = 1;
    secondLinePage.value = 1;
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
    <div class="px-4 pt-3 pb-2 flex items-center justify-between gap-2">
      <NextButton
        ghost
        xs
        icon="i-lucide-plus"
        :label="$t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK_BUTTON')"
        @click="openCreateModal"
      />
      <NextButton
        ghost
        xs
        icon="i-lucide-refresh-cw"
        :label="$t('INTEGRATION_SETTINGS.JIRA.REFRESH')"
        :is-loading="isRefreshing"
        @click="refresh"
      />
    </div>

    <!-- Tabs: 1st line vs 2nd line -->
    <div class="px-4 flex gap-4 border-b border-n-weak">
      <button
        type="button"
        class="py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
        :class="
          activeTab === 'first'
            ? 'border-n-brand text-n-slate-12'
            : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
        "
        @click="setTab('first')"
      >
        {{ $t('INTEGRATION_SETTINGS.JIRA.TABS.FIRST_LINE') }} ({{
          firstLineIssues.length
        }})
      </button>
      <button
        type="button"
        class="py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
        :class="
          activeTab === 'second'
            ? 'border-n-brand text-n-slate-12'
            : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
        "
        @click="setTab('second')"
      >
        {{ $t('INTEGRATION_SETTINGS.JIRA.TABS.SECOND_LINE') }} ({{
          secondLineIssues.length
        }})
      </button>
    </div>

    <div v-if="isLoading" class="flex justify-center p-8">
      <Spinner />
    </div>

    <template v-else>
      <div v-if="currentIssues.length === 0" class="flex justify-center p-4">
        <p class="text-sm text-n-slate-11">
          {{
            activeTab === 'first'
              ? $t('INTEGRATION_SETTINGS.JIRA.NO_FIRST_LINE_ISSUES')
              : $t('INTEGRATION_SETTINGS.JIRA.NO_SECOND_LINE_ISSUES')
          }}
        </p>
      </div>

      <div v-else class="space-y-2 px-4 pt-2 pb-2">
        <JiraIssueItem
          v-for="issue in paginatedIssues"
          :key="issue.key"
          :issue="issue"
          :conversation-id="props.conversationId"
          :second-line-project-key="secondLineProjectKey"
          @unlink="unlinkIssue"
          @refresh="loadLinkedIssues"
        />
      </div>

      <!-- Pagination controls -->
      <div
        v-if="totalPages > 1"
        class="px-4 pb-4 flex items-center justify-between"
      >
        <NextButton
          ghost
          xs
          icon="i-lucide-chevron-left"
          :label="$t('INTEGRATION_SETTINGS.JIRA.PAGINATION.PREV')"
          :disabled="currentPage <= 1"
          @click="prevPage"
        />
        <span class="text-xs text-n-slate-11">
          {{
            $t('INTEGRATION_SETTINGS.JIRA.PAGINATION.PAGE_OF', {
              current: currentPage,
              total: totalPages,
            })
          }}
        </span>
        <NextButton
          ghost
          xs
          icon="i-lucide-chevron-right"
          :label="$t('INTEGRATION_SETTINGS.JIRA.PAGINATION.NEXT')"
          :disabled="currentPage >= totalPages"
          @click="nextPage"
        />
      </div>
    </template>

    <CreateOrLinkIssue
      v-if="shouldShowCreateModal"
      :conversation-id="props.conversationId"
      @close="closeCreateModal"
    />
  </div>
</template>
