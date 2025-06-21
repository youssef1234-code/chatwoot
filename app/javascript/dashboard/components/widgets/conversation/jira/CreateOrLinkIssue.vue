<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';
import CreateIssue from './CreateIssue.vue';
import LinkIssue from './LinkIssue.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const activeTab = ref('create');

const tabs = computed(() => [
  {
    key: 'create',
    label: t('INTEGRATION_SETTINGS.JIRA.CREATE'),
  },
  {
    key: 'link',
    label: t('INTEGRATION_SETTINGS.JIRA.LINK.TITLE'),
  },
]);

const isCreateTabActive = computed(() => activeTab.value === 'create');
const isLinkTabActive = computed(() => activeTab.value === 'link');

const switchToTab = (tabKey) => {
  activeTab.value = tabKey;
};

const handleClose = () => {
  emit('close');
};

// Generate conversation title for linking
const conversationTitle = computed(() => {
  return `Conversation #${props.conversationId}`;
});
</script>

<template>
  <Modal :show="true" @close="handleClose">
    <div class="w-full max-w-2xl mx-auto">
      <div class="flex flex-col h-[600px]">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-n-weak">
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.TITLE') }}
          </h2>
        </div>

        <!-- Tab Navigation -->
        <div class="flex border-b border-n-weak">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            class="flex-1 px-6 py-3 text-sm font-medium transition-colors"
            :class="[
              activeTab === tab.key
                ? 'text-blue-600 border-b-2 border-blue-600 bg-blue-50'
                : 'text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2'
            ]"
            @click="switchToTab(tab.key)"
          >
            {{ tab.label }}
          </button>
        </div>

        <!-- Tab Content -->
        <div class="flex-1 overflow-hidden">
          <CreateIssue
            v-if="isCreateTabActive"
            :conversation-id="conversationId"
            @close="handleClose"
          />
          <LinkIssue
            v-if="isLinkTabActive"
            :conversation-id="conversationId"
            :title="conversationTitle"
            @close="handleClose"
          />
        </div>
      </div>
    </div>
  </Modal>
</template>
