<script setup>
import { ref, onMounted } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import IntegrationHooks from './IntegrationHooks.vue';
import Spinner from 'shared/components/Spinner.vue';

const store = useStore();
const integrationLoaded = ref(false);

const uiFlags = useMapGetter('integrations/getUIFlags');

onMounted(async () => {
  await store.dispatch('integrations/get', 'whatsapp_bridge');
  integrationLoaded.value = true;
});
</script>

<template>
  <div class="flex-grow flex-shrink p-4 overflow-auto max-w-6xl mx-auto">
    <div v-if="integrationLoaded && !uiFlags.isFetching">
      <IntegrationHooks integration-id="whatsapp_bridge" />
    </div>
    <div v-else class="flex items-center justify-center flex-1">
      <Spinner size="" color-scheme="primary" />
    </div>
  </div>
</template>
