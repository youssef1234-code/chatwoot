<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import JiraAPI from 'dashboard/api/integrations/jira';

const props = defineProps({
  issueKey: {
    type: String,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const isLoading = ref(false);
const issue = ref(null);

const statusColor = computed(() => {
  if (!issue.value?.status) return 'bg-gray-600 text-white';
  
  const status = issue.value.status.toLowerCase();
  if (status.includes('done') || status.includes('closed') || status.includes('resolved')) {
    return 'bg-green-600 text-white shadow-green-100';
  } else if (status.includes('progress') || status.includes('active') || status.includes('development')) {
    return 'bg-blue-600 text-white shadow-blue-100';
  } else if (status.includes('review') || status.includes('testing') || status.includes('test')) {
    return 'bg-amber-600 text-white shadow-amber-100';
  } else if (status.includes('todo') || status.includes('open') || status.includes('backlog')) {
    return 'bg-slate-600 text-white shadow-slate-100';
  } else if (status.includes('waiting') || status.includes('blocked')) {
    return 'bg-red-600 text-white shadow-red-100';
  }
  return 'bg-gray-600 text-white shadow-gray-100';
});

const priorityColor = computed(() => {
  if (!issue.value?.priority) return 'text-gray-700 bg-gray-100';
  
  const priority = issue.value.priority.toLowerCase();
  if (priority.includes('highest') || priority.includes('critical')) {
    return 'text-red-700 bg-red-100';
  } else if (priority.includes('high')) {
    return 'text-orange-700 bg-orange-100';
  } else if (priority.includes('medium')) {
    return 'text-yellow-700 bg-yellow-100';
  } else if (priority.includes('low')) {
    return 'text-blue-700 bg-blue-100';
  }
  return 'text-gray-700 bg-gray-100';
});

const fetchIssue = async () => {
  if (!props.issueKey) return;
  
  isLoading.value = true;
  try {
    const response = await JiraAPI.getIssue(props.issueKey);
    issue.value = response.data;
  } catch (error) {
    console.error('Failed to fetch JIRA issue:', error);
  } finally {
    isLoading.value = false;
  }
};

const openInJira = () => {
  if (issue.value?.url) {
    window.open(issue.value.url, '_blank');
  }
};

onMounted(fetchIssue);
</script>

<template>
  <div 
    v-if="issue" 
    class="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-300 bg-white hover:bg-gray-50 transition-all duration-200 cursor-pointer shadow-sm hover:shadow-md"
    @click="openInJira"
  >
    <div class="flex items-center gap-2">
      <!-- JIRA Icon -->
      <div class="w-5 h-5 bg-gradient-to-br from-blue-600 to-blue-700 rounded text-white text-xs flex items-center justify-center font-bold shadow-sm">
        J
      </div>
      
      <!-- Issue Key -->
      <span class="text-sm font-semibold text-blue-700 hover:text-blue-800">
        {{ issueKey }}
      </span>
      
      <!-- Status Badge -->
      <span 
        class="px-2.5 py-1 rounded-full text-xs font-medium shadow-sm border"
        :class="statusColor"
      >
        {{ issue.status }}
      </span>
      
      <!-- Priority (if not compact) -->
      <span 
        v-if="!compact && issue.priority"
        class="px-2 py-1 rounded-md text-xs font-medium border"
        :class="priorityColor"
      >
        {{ issue.priority }}
      </span>
      
      <!-- External link icon -->
      <i class="ri-external-link-line text-sm text-gray-500 hover:text-gray-700" />
    </div>
    
    <!-- Loading indicator -->
    <div v-if="isLoading" class="w-3 h-3 border border-blue-600 border-t-transparent rounded-full animate-spin" />
  </div>
  
  <!-- Loading state when no issue data -->
  <div 
    v-else-if="isLoading"
    class="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-300 bg-white shadow-sm"
  >
    <div class="w-5 h-5 bg-gray-300 rounded animate-pulse" />
    <div class="w-16 h-4 bg-gray-300 rounded animate-pulse" />
    <div class="w-12 h-4 bg-gray-300 rounded animate-pulse" />
  </div>
  
  <!-- Error/empty state -->
  <div 
    class="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-red-200 bg-red-50 text-red-700 shadow-sm"
  >
    <div class="w-5 h-5 bg-red-500 rounded text-white text-xs flex items-center justify-center font-bold">
      J
    </div>
    <span class="text-sm font-medium">{{ issueKey }}</span>
    <span class="text-xs bg-red-100 px-2 py-0.5 rounded border border-red-200">({{ $t('INTEGRATION.JIRA.ISSUE_NOT_FOUND') }})</span>
  </div>
</template>
