<script setup>
import { computed, nextTick } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const { uiSettings, updateUISettings, toggleSidebarUIState } = useUISettings();

const jiraIntegration = computed(() => store.getters['integrations/getAppIntegrations']?.find(i => i.id === 'jira'));
const isJiraConnected = computed(() => jiraIntegration.value?.enabled);

const isContactSidebarOpen = computed(() => uiSettings.value.is_contact_sidebar_open);
const isJiraIssuesOpen = computed(() => uiSettings.value.is_jira_issues_open);

const dispatchJiraEvent = () => {
  const event = new CustomEvent('jira:open-create-link', {
    detail: { conversationId: props.conversationId }
  });
  window.dispatchEvent(event);
};

const openJiraModal = async () => {
  console.log('JIRA Button: Opening modal, current sidebar state:', {
    isContactSidebarOpen: isContactSidebarOpen.value,
    isJiraIssuesOpen: isJiraIssuesOpen.value,
    conversationId: props.conversationId
  });
  
  // If sidebar is not open, open it first
  if (!isContactSidebarOpen.value) {
    console.log('JIRA Button: Opening contact sidebar');
    updateUISettings({
      is_contact_sidebar_open: true,
    });
  }
  
  // If JIRA issues section is not open, open it
  if (!isJiraIssuesOpen.value) {
    console.log('JIRA Button: Opening JIRA issues section');
    toggleSidebarUIState('is_jira_issues_open', true);
  }
  
  // Wait for the DOM to update and component to mount
  await nextTick();
  
  // Small delay to ensure the component is fully mounted and event listeners are registered
  setTimeout(() => {
    console.log('JIRA Button: Dispatching jira:open-create-link event');
    dispatchJiraEvent();
  }, 100);
};
</script>

<template>
  <div v-if="isJiraConnected" class="flex items-center">
    <ButtonV4
      size="sm"
      variant="ghost"
      color="slate"
      icon="i-lucide-plus"
      class="rounded-md"
      :title="t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK_BUTTON')"
      @click="openJiraModal"
    >
      <span class="ml-1 text-xs font-medium">J</span>
    </ButtonV4>
  </div>
</template>
