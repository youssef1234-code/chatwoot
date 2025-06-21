<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { useToggle } from '@vueuse/core';
import JiraAPI from 'dashboard/api/integrations/jira';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const [showDropdown, toggleDropdown] = useToggle(false);
const linkedIssues = ref([]);
const isLoading = ref(false);

const jiraIntegration = computed(() => store.getters['integrations/getAppIntegrations']?.find(i => i.id === 'jira'));
const isJiraConnected = computed(() => jiraIntegration.value?.enabled);
const hasLinkedIssues = computed(() => linkedIssues.value && linkedIssues.value.length > 0);
const issueCount = computed(() => linkedIssues.value ? linkedIssues.value.length : 0);

const menuItems = computed(() => {
  const items = [];
  
  if (hasLinkedIssues.value) {
    // Show ALL linked issues in the dropdown, not just a subset
    linkedIssues.value.forEach((issue, index) => {
      const summary = issue.summary || issue.title || '';
      const truncatedSummary = summary.length > 40 ? `${summary.substring(0, 40)}...` : summary;
      
      items.push({
        icon: 'i-lucide-external-link',
        label: `${issue.key}: ${truncatedSummary}`,
        action: 'open_issue',
        value: issue.key,
        url: issue.url,
      });
    });
    
    if (items.length > 0) {
      items.push({ type: 'divider' });
    }
  }
  
  items.push({
    icon: 'i-lucide-plus',
    label: t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK_BUTTON'),
    action: 'create_or_link',
    value: 'create_or_link',
  });
  
  return items;
});

const fetchLinkedIssues = async () => {
  if (!isJiraConnected.value) return;
  
  isLoading.value = true;
  try {
    const response = await JiraAPI.getLinkedIssues(props.conversationId);
    linkedIssues.value = response.data || [];
  } catch (error) {
    console.error('Failed to fetch linked JIRA issues:', error);
    linkedIssues.value = [];
  } finally {
    isLoading.value = false;
  }
};

const handleAction = ({ action, value, url }) => {
  toggleDropdown(false);
  
  if (action === 'open_issue' && url) {
    window.open(url, '_blank');
  } else if (action === 'create_or_link') {
    // Emit event to open create/link modal
    const event = new CustomEvent('jira:open-create-link', {
      detail: { conversationId: props.conversationId }
    });
    window.dispatchEvent(event);
  }
};

const displayText = computed(() => {
  if (isLoading.value) return '';
  if (!hasLinkedIssues.value) return 'J';
  
  // Show "+n" format when there are more than 2 issues to indicate there are more
  if (issueCount.value > 2) {
    return `+${issueCount.value}`;
  }
  
  return issueCount.value.toString();
});

const buttonClass = computed(() => {
  const baseClass = 'rounded-md transition-all duration-200';
  if (isLoading.value) return `${baseClass} animate-spin`;
  return baseClass;
});

const buttonIcon = computed(() => {
  if (isLoading.value) return 'i-lucide-loader-2';
  return hasLinkedIssues.value ? 'i-lucide-link' : 'i-lucide-plus';
});

const handleOpenAllIssues = (event) => {
  if (event.detail?.conversationId === props.conversationId) {
    toggleDropdown(true);
  }
};

onMounted(() => {
  if (isJiraConnected.value) {
    fetchLinkedIssues();
  }
  
  // Listen for updates from other JIRA components
  window.addEventListener('jira:issues-updated', fetchLinkedIssues);
  
  // Listen for "open all issues" event from JIRA tags
  window.addEventListener('jira:open-all-issues', handleOpenAllIssues);
});

onUnmounted(() => {
  window.removeEventListener('jira:issues-updated', fetchLinkedIssues);
  window.removeEventListener('jira:open-all-issues', handleOpenAllIssues);
});
</script>

<template>
  <div
    v-if="isJiraConnected"
    v-on-clickaway="() => toggleDropdown(false)"
    class="relative flex items-center"
    :data-conversation-id="conversationId"
  >
    <ButtonV4
      size="sm"
      :variant="hasLinkedIssues ? 'solid' : 'ghost'"
      :color="hasLinkedIssues ? 'primary' : 'slate'"
      :icon="buttonIcon"
      :class="buttonClass"
      class="min-w-[60px] justify-center relative jira-issues-button"
      :title="hasLinkedIssues ? `${issueCount} linked JIRA issue${issueCount > 1 ? 's' : ''} - Click to view all` : 'Connect to JIRA'"
      @click="toggleDropdown()"
    >
      <!-- Badge for linked issues count -->
      <span 
        v-if="hasLinkedIssues" 
        class="ml-1.5 text-xs font-semibold text-white bg-white/20 dark:bg-white/30 px-1.5 py-0.5 rounded-full min-w-[18px] text-center transition-all duration-200"
        :class="{
          'animate-pulse': issueCount > 2,
          'hover:bg-white/30 dark:hover:bg-white/40': issueCount > 2
        }"
      >
        {{ displayText }}
      </span>
      <!-- Default text for no issues -->
      <span v-else class="ml-1 text-xs font-medium">
        J
      </span>
    </ButtonV4>
    
    <DropdownMenu
      v-if="showDropdown"
      :menu-items="menuItems"
      class="mt-2 ltr:right-0 rtl:left-0 top-full min-w-80 max-w-96 z-50"
      @action="handleAction"
    />
  </div>
</template>

<style scoped>
.jira-issue-item {
  max-width: 250px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
