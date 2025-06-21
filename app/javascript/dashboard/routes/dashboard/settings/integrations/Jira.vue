<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';

import Integration from './Integration.vue';
import Spinner from 'shared/components/Spinner.vue';

const store = useStore();
const integrationLoaded = ref(false);
const isConnecting = ref(false);

const integration = useFunctionGetter('integrations/getIntegration', 'jira');
const uiFlags = useMapGetter('integrations/getUIFlags');

const integrationAction = computed(() => {
  if (integration.value.enabled) {
    return 'disconnect';
  }
  return 'connect';
});

const initializeJiraIntegration = async () => {
  await store.dispatch('integrations/get', 'jira');
  integrationLoaded.value = true;
};

const handleConnect = async () => {
  try {
    isConnecting.value = true;
    
    const response = await fetch('/jira/connect', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
      }
    });
    
    const result = await response.json();
    
    if (response.ok && result.success) {
      useAlert('JIRA integration connected successfully!');
      await initializeJiraIntegration();
    } else {
      useAlert(result.error || 'Failed to connect to JIRA');
    }
  } catch (error) {
    console.error('JIRA connection error:', error);
    useAlert('Failed to connect to JIRA. Please try again.');
  } finally {
    isConnecting.value = false;
  }
};

const handleDisconnect = async () => {
  try {
    await store.dispatch('integrations/deleteIntegration', 'jira');
    await initializeJiraIntegration();
    useAlert('JIRA integration disconnected successfully');
  } catch (error) {
    console.error('Failed to disconnect JIRA integration:', error);
    useAlert('Failed to disconnect JIRA integration');
  }
};

onMounted(() => {
  initializeJiraIntegration();
});
</script>

<template>
  <div class="flex-grow flex-shrink p-4 overflow-auto max-w-6xl mx-auto">
    <div v-if="integrationLoaded && !uiFlags.isCreatingJira">
      <Integration
        :integration-id="integration.id"
        :integration-logo="integration.logo"
        :integration-name="integration.name"
        :integration-description="integration.description"
        :integration-enabled="integration.enabled"
        :integration-action="integrationAction"
        :delete-confirmation-text="{
          title: $t('INTEGRATION_SETTINGS.JIRA.DELETE.TITLE'),
          message: $t('INTEGRATION_SETTINGS.JIRA.DELETE.MESSAGE'),
        }"
        :is-connecting="isConnecting"
        @connect="handleConnect"
        @delete="handleDisconnect"
      />
    </div>
    <div v-else class="flex items-center justify-center flex-1">
      <Spinner size="" color-scheme="primary" />
    </div>
  </div>
</template>
