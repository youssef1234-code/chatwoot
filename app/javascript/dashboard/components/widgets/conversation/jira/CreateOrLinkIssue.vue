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
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
  showHeader: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['close', 'issue-created', 'issue-linked']);

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

const handleIssueCreated = (issueData) => {
  emit('issue-created', issueData);
};

const handleIssueLinked = (issueData) => {
  emit('issue-linked', issueData);
};

// Generate conversation title for linking
const conversationTitle = computed(() => {
  return `Conversation #${props.conversationId}`;
});
</script>

<template>
  <div v-if="!showHeader" class="w-full">
    <!-- Embedded mode for EscalateToJiraModal -->
    <!-- Tab Navigation -->
    <div class="flex border-b border-slate-200 dark:border-slate-600">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        class="flex-1 px-6 py-3 text-sm font-medium transition-colors"
        :class="[
          activeTab === tab.key
            ? 'text-blue-600 dark:text-blue-400 border-b-2 border-blue-600 dark:border-blue-400 bg-blue-50 dark:bg-blue-900/30'
            : 'text-slate-600 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700'
        ]"
        @click="switchToTab(tab.key)"
      >
        {{ tab.label }}
      </button>
    </div>

    <!-- Tab Content -->
    <div class="overflow-hidden p-6">
      <CreateIssue
        v-if="isCreateTabActive"
        :conversation-id="conversationId"
        :title="title"
        :description="description"
        @close="handleClose"
        @issue-created="handleIssueCreated"
      />
      <LinkIssue
        v-if="isLinkTabActive"
        :conversation-id="conversationId"
        :title="conversationTitle"
        @close="handleClose"
        @issue-linked="handleIssueLinked"
      />
    </div>
  </div>
  
  <!-- Modal mode for standalone use -->
  <Modal v-else :show="true" @close="handleClose">
    <div class="w-full max-w-2xl mx-auto">
      <div class="flex flex-col h-[600px]">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600">
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {{ $t('INTEGRATION_SETTINGS.JIRA.ADD_OR_LINK.TITLE') }}
          </h2>
        </div>

        <!-- Tab Navigation -->
        <div class="flex border-b border-slate-200 dark:border-slate-600">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            class="flex-1 px-6 py-3 text-sm font-medium transition-colors"
            :class="[
              activeTab === tab.key
                ? 'text-blue-600 dark:text-blue-400 border-b-2 border-blue-600 dark:border-blue-400 bg-blue-50 dark:bg-blue-900/30'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700'
            ]"
            @click="switchToTab(tab.key)"
          >
            {{ tab.label }}
          </button>
        </div>

        <!-- Tab Content -->
        <div class="flex-1 overflow-y-auto">
          <CreateIssue
            v-if="isCreateTabActive"
            :conversation-id="conversationId"
            :title="title"
            :description="description"
            @close="handleClose"
            @issue-created="handleIssueCreated"
          />
          <LinkIssue
            v-if="isLinkTabActive"
            :conversation-id="conversationId"
            :title="conversationTitle"
            @close="handleClose"
            @issue-linked="handleIssueLinked"
          />
        </div>
      </div>
    </div>
  </Modal>
</template>
