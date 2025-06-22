<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';

import IntegrationHooks from './IntegrationHooks.vue';
import Spinner from 'shared/components/Spinner.vue';

const store = useStore();
const integrationLoaded = ref(false);
const isProcessing = ref(false);

const integration = useFunctionGetter('integrations/getIntegration', 'jira');
const uiFlags = useMapGetter('integrations/getUIFlags');

const integrationAction = computed(() => {
  return integration.value.enabled ? 'disconnect' : 'connect';
});

const initializeJiraIntegration = async () => {
  await store.dispatch('integrations/get', 'jira');
  integrationLoaded.value = true;
};

const handleConnect = async () => {
  isProcessing.value = true;
  try {
    await store.dispatch('integrations/createIntegration', 'jira');
    useAlert('JIRA integration connected successfully!');
    await initializeJiraIntegration();
  } catch (error) {
    useAlert('Failed to connect to JIRA. Please try again.');
  } finally {
    isProcessing.value = false;
  }
};

const handleDisconnect = async () => {
  isProcessing.value = true;
  try {
    await store.dispatch('integrations/deleteIntegration', 'jira');
    useAlert('JIRA integration disconnected successfully');
    await initializeJiraIntegration();
  } catch (error) {
    useAlert('Failed to disconnect JIRA integration');
  } finally {
    isProcessing.value = false;
  }
};

onMounted(() => {
  initializeJiraIntegration();
});
</script>

<template>
  <div class="flex-grow flex-shrink p-4 overflow-auto max-w-6xl mx-auto">
    <div v-if="integrationLoaded && !uiFlags.isCreatingJira">
      <IntegrationHooks integration-id="jira" />
    </div>
    <div v-else class="flex items-center justify-center flex-1">
      <Spinner size="" color-scheme="primary" />
    </div>
  </div>
</template>
