<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import JiraAPI from 'dashboard/api/integrations/jira';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const linkedIssues = ref([]);
const isLoading = ref(false);

const hasIssues = computed(() => linkedIssues.value.length > 0);

const loadLinkedIssues = async () => {
  if (!props.conversationId) return;
  
  isLoading.value = true;
  try {
    const response = await JiraAPI.getLinkedIssues(props.conversationId);
    linkedIssues.value = response.data || [];
  } catch (error) {
    console.error('Failed to load linked JIRA issues:', error);
    linkedIssues.value = [];
  } finally {
    isLoading.value = false;
  }
};

const openIssue = (issue) => {
  if (issue.url) {
    window.open(issue.url, '_blank');
  }
};

onMounted(() => {
  loadLinkedIssues();
  
  // Listen for JIRA issue changes
  window.addEventListener('jira:issues-updated', loadLinkedIssues);
});

// Cleanup listener
onBeforeUnmount(() => {
  window.removeEventListener('jira:issues-updated', loadLinkedIssues);
});
</script>

<template>
  <div v-if="hasIssues" class="flex items-center gap-1">
    <ButtonV4
      v-for="issue in linkedIssues.slice(0, 2)"
      :key="issue.key"
      size="sm"
      variant="ghost"
      color="slate"
      class="!h-8 !px-2 !py-1 !text-xs !font-medium hover:bg-blue-50 hover:text-blue-700"
      @click="openIssue(issue)"
    >
      <div class="w-3 h-3 bg-blue-600 rounded text-black text-[10px] flex items-center justify-center font-bold mr-1">
        J
      </div>
      <span class="truncate max-w-[80px]" :title="issue.summary">
        {{ issue.key }}
      </span>
    </ButtonV4>
    
    <ButtonV4
      v-if="linkedIssues.length > 2"
      size="sm"
      variant="ghost"
      color="slate"
      class="!h-8 !px-2 !py-1 !text-xs !font-medium"
      disabled
    >
      +{{ linkedIssues.length - 2 }}
    </ButtonV4>
  </div>
</template>
