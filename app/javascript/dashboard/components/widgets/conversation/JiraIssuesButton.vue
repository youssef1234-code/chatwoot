<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();

const jiraIntegration = computed(() => store.getters['integrations/getAppIntegrations']?.find(i => i.id === 'jira'));
const isJiraConnected = computed(() => jiraIntegration.value?.enabled);

const openJiraModal = () => {
  // Emit event to open create/link modal
  const event = new CustomEvent('jira:open-create-link', {
    detail: { conversationId: props.conversationId }
  });
  window.dispatchEvent(event);
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
