<template>
  <div class="flex flex-col w-full h-full m-0 p-6 sm:py-8 lg:px-16 overflow-auto bg-n-background font-inter">
    <div class="flex flex-col w-full max-w-full mx-auto">
      <!-- Header -->
      <div class="bg-white dark:bg-n-slate-1 border-b border-n-weak p-6 rounded-lg mb-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
              {{ $t('TICKETS.TRACKING.TITLE') }}
            </h1>
            <p class="text-sm text-n-slate-10">
              {{ $t('TICKETS.TRACKING.DESCRIPTION') }}
            </p>
          </div>
          <div class="flex items-center gap-3">
          <!-- AI Enhancement Toggle -->
          <NextButton
            v-if="isAiEnabled"
            :variant="isAiEnhancementEnabled ? 'solid' : 'outline'"
            color="blue"
            size="sm"
            :is-loading="isAiLoading"
            @click="toggleAiEnhancement"
          >
            <Icon icon="i-lucide-sparkles" class="w-4 h-4 mr-2" />
            {{ $t('TICKETS.TRACKING.AI_ENHANCEMENT') }}
          </NextButton>
          
          <!-- Refresh Button -->
          <NextButton
            variant="outline"
            size="sm"
            :is-loading="isLoading"
            @click="refreshTickets"
          >
            <Icon icon="i-lucide-refresh-cw" class="w-4 h-4 mr-2" />
            {{ $t('TICKETS.TRACKING.REFRESH') }}
          </NextButton>          </div>
        </div>
      </div>

      <!-- Filters and Search -->
      <div class="bg-white dark:bg-n-slate-1 border-b border-n-weak p-4 rounded-lg mb-6">
        <div class="flex flex-wrap items-center gap-4">
        <!-- Search Input -->
        <div class="flex-1 min-w-72">
          <NextInput
            v-model="searchQuery"
            :placeholder="$t('TICKETS.TRACKING.SEARCH_PLACEHOLDER')"
            type="search"
            size="sm"
          >
            <template #leading>
              <Icon icon="i-lucide-search" class="w-4 h-4 text-n-slate-9" />
            </template>
          </NextInput>
        </div>

        <!-- Status Filter -->
        <NextSelect
          v-model="selectedStatus"
          :label="$t('TICKETS.TRACKING.STATUS_FILTER')"
          name="status"
          :options="statusOptions"
          :placeholder="$t('TICKETS.TRACKING.STATUS_FILTER')"
          class="min-w-40"
        />

        <!-- Priority Filter -->
        <NextSelect
          v-model="selectedPriority"
          :label="$t('TICKETS.TRACKING.PRIORITY_FILTER')"
          name="priority"
          :options="priorityOptions"
          :placeholder="$t('TICKETS.TRACKING.PRIORITY_FILTER')"
          class="min-w-40"
        />

        <!-- Agent Filter -->
        <NextSelect
          v-model="selectedAgent"
          :label="$t('TICKETS.TRACKING.AGENT_FILTER')"
          name="agent"
          :options="agentOptions"
          :placeholder="$t('TICKETS.TRACKING.AGENT_FILTER')"
          class="min-w-40"
        />

        <!-- Category Filter -->
        <NextSelect
          v-model="selectedCategory"
          :label="$t('TICKETS.TRACKING.CATEGORY_FILTER')"
          name="category"
          :options="categoryOptions"
          :placeholder="$t('TICKETS.TRACKING.CATEGORY_FILTER')"
          class="min-w-40"
        />

        <!-- JIRA Filter -->
        <NextSelect
          v-model="selectedJiraStatus"
          :label="$t('TICKETS.TRACKING.JIRA_FILTER')"
          name="jira"
          :options="jiraOptions"
          :placeholder="$t('TICKETS.TRACKING.JIRA_FILTER')"
          class="min-w-40"
        />

        <!-- Plane Filter -->
        <NextSelect
          v-model="selectedPlaneStatus"
          :label="$t('TICKETS.TRACKING.PLANE_FILTER')"
          name="plane"
          :options="planeOptions"
          :placeholder="$t('TICKETS.TRACKING.PLANE_FILTER')"
          class="min-w-40"
        />

        <!-- Date Range Filter -->
        <NextButton
          variant="outline"
          size="sm"
          @click="showDatePicker = !showDatePicker"
        >
          <Icon icon="i-lucide-calendar" class="w-4 h-4 mr-2" />
          {{ $t('TICKETS.TRACKING.DATE_RANGE') }}
        </NextButton>

        <!-- Clear Filters -->
        <NextButton
          v-if="hasActiveFilters"
          variant="ghost"
          size="sm"
          color="red"
          @click="clearFilters"
        >
          {{ $t('TICKETS.TRACKING.CLEAR_FILTERS') }}
        </NextButton>
      </div>
      </div>

      <!-- Kanban Board -->
      <div class="flex-1 min-h-96 bg-white dark:bg-n-slate-1 rounded-lg p-4">
        <TicketsKanbanBoard
          :tickets="filteredTickets"
          :is-loading="isLoading"
          :current-user="currentUser"
          :is-ai-enhancement-enabled="isAiEnhancementEnabled"
          @ticket-updated="handleTicketUpdate"
          @refresh="refreshTickets"
          @enhance-with-ai="enhanceTicketWithAi"
        />
      </div>

      <!-- AI Enhancement Modal -->
      <AiEnhancementModal
        v-if="showAiModal"
        :ticket="selectedTicketForAi"
        @close="closeAiModal"
        @enhanced="handleAiEnhancement"
      />
    </div>
  </div>
</template>

<script>
import { computed, ref, onMounted, onUnmounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';

import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextSelect from 'v3/components/Form/Select.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

import TicketsKanbanBoard from './components/TicketsKanbanBoard.vue';
import AiEnhancementModal from './components/AiEnhancementModal.vue';

import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';

export default {
  name: 'TicketsIndex',
  components: {
    NextButton,
    NextInput,
    NextSelect,
    Icon,
    TicketsKanbanBoard,
    AiEnhancementModal,
  },
  setup() {
    const store = useStore();
    const { t } = useI18n();
    const { accountId } = useAccount();
    
    // State
    const isLoading = ref(false);
    const isAiLoading = ref(false);
    const searchQuery = ref('');
    const selectedStatus = ref('');
    const selectedPriority = ref('');
    const selectedAgent = ref('');
    const selectedCategory = ref('');
    const selectedJiraStatus = ref('');
    const selectedPlaneStatus = ref('');
    const showDatePicker = ref(false);
    const isAiEnhancementEnabled = ref(false);
    const showAiModal = ref(false);
    const selectedTicketForAi = ref(null);

    // Computed
    const currentUser = computed(() => store.getters.getCurrentUser);
    const tickets = computed(() => store.getters['tickets/getTickets']);
    const isAiEnabled = true; // This could be a prop or a store state

    const statusOptions = computed(() => [
      { label: t('TICKETS.FILTERS.ALL'), value: '' },
      { label: t('TICKETS.FILTERS.OPEN'), value: 'open' },
      { label: t('TICKETS.FILTERS.IN_PROGRESS'), value: 'in_progress' },
      { label: t('TICKETS.FILTERS.ESCALATED'), value: 'escalated' },
      { label: t('TICKETS.FILTERS.RESOLVED'), value: 'resolved' },
      { label: t('TICKETS.FILTERS.CLOSED'), value: 'closed' },
    ]);

    const priorityOptions = computed(() => [
      { label: t('TICKETS.FILTERS.ALL'), value: '' },
      { label: t('TICKETS.PRIORITY.LOW'), value: 'low' },
      { label: t('TICKETS.PRIORITY.MEDIUM'), value: 'medium' },
      { label: t('TICKETS.PRIORITY.HIGH'), value: 'high' },
      { label: t('TICKETS.PRIORITY.URGENT'), value: 'urgent' },
    ]);

    const agentOptions = computed(() => {
      const agents = store.getters['agents/getAgents'];
      return [
        { label: t('TICKETS.FILTERS.ALL'), value: '' },
        { label: t('TICKETS.FILTERS.ASSIGNED_TO_ME'), value: currentUser.value.id },
        ...agents.map(agent => ({
          label: agent.name,
          value: agent.id,
        })),
      ];
    });
  
    const currentAccount = computed(() => {
      const accountId = store.getters.getCurrentAccountId;
      const accountFromAccountsStore =
      store.getters["accounts/getAccount"](accountId);
      if (accountFromAccountsStore && Object.keys(accountFromAccountsStore).length > 0) {
        return accountFromAccountsStore;
      }
    });


    const categoryOptions = computed(() => {
      const categories = currentAccount.value?.settings?.ticket_categories || [];
      return [
        { label: t('TICKETS.FILTERS.ALL'), value: '' },
        ...categories.map(category => ({
          label: category,
          value: category,
        })),
      ];
    });

    const jiraOptions = computed(() => [
      { label: t('TICKETS.FILTERS.ALL'), value: '' },
      { label: t('TICKETS.FILTERS.LINKED_TO_JIRA'), value: 'linked' },
      { label: t('TICKETS.FILTERS.NOT_LINKED_TO_JIRA'), value: 'not_linked' },
    ]);

    const planeOptions = computed(() => [
      { label: t('TICKETS.FILTERS.ALL'), value: '' },
      { label: t('TICKETS.FILTERS.LINKED_TO_PLANE'), value: 'linked' },
      { label: t('TICKETS.FILTERS.NOT_LINKED_TO_PLANE'), value: 'not_linked' },
    ]);

    const hasActiveFilters = computed(() => {
      return selectedStatus.value || selectedPriority.value || selectedAgent.value || selectedCategory.value || selectedJiraStatus.value || selectedPlaneStatus.value || searchQuery.value;
    });

    const filteredTickets = computed(() => {
      let filtered = [...tickets.value];

      // Apply search filter
      if (searchQuery.value) {
        let query = searchQuery.value.trim();
        
        console.log('Search query:', query); // Debug log
        console.log('Query length:', query.length); // Debug log
        console.log('Query starts with #:', query.startsWith('#')); // Debug log
        
        // Check if search starts with # for ticket ID search
        if (query.startsWith('#')) {
          const ticketId = query.substring(1).trim();
          console.log('Searching for ticket ID:', ticketId); // Debug log
          console.log('Tickets available:', filtered.map(t => t.id)); // Debug log
          if (ticketId) {
            // Filter by ticket ID (exact or partial match)
            const matchingTickets = filtered.filter(ticket => 
              ticket.id.toString().includes(ticketId)
            );
            console.log('Matching tickets:', matchingTickets.map(t => t.id)); // Debug log
            filtered = matchingTickets;
          }
        } else {
          // Regular text search
          const searchTerm = query.toLowerCase();
          filtered = filtered.filter(ticket => 
            ticket.title?.toLowerCase().includes(searchTerm) ||
            ticket.description?.toLowerCase().includes(searchTerm) ||
            ticket.id.toString().includes(searchTerm) ||
            ticket.assigned_agent?.name?.toLowerCase().includes(searchTerm) ||
            ticket.created_by?.name?.toLowerCase().includes(searchTerm)
          );
        }
      }

      // Apply status filter
      if (selectedStatus.value) {
        filtered = filtered.filter(ticket => ticket.status === selectedStatus.value);
      }

      // Apply priority filter
      if (selectedPriority.value) {
        filtered = filtered.filter(ticket => ticket.priority === selectedPriority.value);
      }

      // Apply agent filter
      if (selectedAgent.value) {
        if (selectedAgent.value === currentUser.value.id) {
          filtered = filtered.filter(ticket => 
            ticket.assigned_agent?.id === currentUser.value.id ||
            ticket.created_by?.id === currentUser.value.id
          );
        } else {
          filtered = filtered.filter(ticket => ticket.assigned_agent?.id === selectedAgent.value);
        }
      } else {
        // Default: show only agent's tickets initially
        filtered = filtered.filter(ticket => 
          ticket.assigned_agent?.id === currentUser.value.id ||
          ticket.created_by?.id === currentUser.value.id
        );
      }

      // Apply category filter
      if (selectedCategory.value && selectedCategory.value !== 'all') {
        filtered = filtered.filter(ticket => ticket.category === selectedCategory.value);
      }

      // Apply JIRA filter
      if (selectedJiraStatus.value) {
        if (selectedJiraStatus.value === 'linked') {
          filtered = filtered.filter(ticket => ticket.jira_issue_key);
        } else if (selectedJiraStatus.value === 'not_linked') {
          filtered = filtered.filter(ticket => !ticket.jira_issue_key);
        }
      }

      // Apply Plane filter
      if (selectedPlaneStatus.value) {
        if (selectedPlaneStatus.value === 'linked') {
          filtered = filtered.filter(ticket => ticket.plane_issue_id);
        } else if (selectedPlaneStatus.value === 'not_linked') {
          filtered = filtered.filter(ticket => !ticket.plane_issue_id);
        }
      }

      // Sort by ID in descending order (newest first)
      return filtered.sort((a, b) => b.id - a.id);
    });

    // Methods
    const loadTickets = async () => {
      isLoading.value = true;
      try {
        const params = {
          assigned_agent_id: currentUser.value.id, // Default to agent's tickets
        };
        await store.dispatch('tickets/fetchTickets', params);
      } catch (error) {
        console.error('Failed to load tickets:', error);
        useAlert(t('TICKETS.TRACKING.LOAD_ERROR'));
      } finally {
        isLoading.value = false;
      }
    };

    const refreshTickets = async () => {
      await loadTickets();
      useAlert(t('TICKETS.TRACKING.REFRESHED'));
    };

    const clearFilters = () => {
      searchQuery.value = '';
      selectedStatus.value = '';
      selectedPriority.value = '';
      selectedAgent.value = '';
      selectedCategory.value = '';
      selectedJiraStatus.value = '';
      selectedPlaneStatus.value = '';
    };

    const toggleAiEnhancement = async () => {
      if (!isAiEnhancementEnabled.value) {
        isAiLoading.value = true;
        try {
          // Enable AI enhancement - could involve API call to prepare AI context
          isAiEnhancementEnabled.value = true;
          useAlert(t('TICKETS.TRACKING.AI_ENABLED'));
        } catch (error) {
          console.error('Failed to enable AI enhancement:', error);
          useAlert(t('TICKETS.TRACKING.AI_ERROR'));
        } finally {
          isAiLoading.value = false;
        }
      } else {
        isAiEnhancementEnabled.value = false;
        useAlert(t('TICKETS.TRACKING.AI_DISABLED'));
      }
    };

    const enhanceTicketWithAi = (ticket) => {
      selectedTicketForAi.value = ticket;
      showAiModal.value = true;
    };

    const closeAiModal = () => {
      showAiModal.value = false;
      selectedTicketForAi.value = null;
    };

    const handleAiEnhancement = async (enhancedData) => {
      try {
        await store.dispatch('tickets/updateTicket', {
          id: selectedTicketForAi.value.id,
          ...enhancedData,
        });
        useAlert(t('TICKETS.TRACKING.AI_ENHANCED'));
        closeAiModal();
      } catch (error) {
        console.error('Failed to apply AI enhancement:', error);
        useAlert(t('TICKETS.TRACKING.AI_ENHANCEMENT_ERROR'));
      }
    };

    const handleTicketUpdate = () => {
      // Refresh tickets when updated
      loadTickets();
    };

    // WebSocket event handlers
    const handleTicketCreated = (data) => {
      console.log('New ticket created via WebSocket:', data);
      store.dispatch('tickets/addTicket', data);
    };

    const handleTicketUpdated = (data) => {
      store.dispatch('tickets/updateTicketFromWebSocket', data);
    };

    const handleJiraIssueUpdated = (data) => {
      // Refresh tickets if JIRA status changed
      loadTickets();
    };

    // Lifecycle
    onMounted(() => {
      loadTickets();
      
      // Load agents for filters
      store.dispatch('agents/get');
      
      // Set up WebSocket listeners
      emitter.on('tickets:ticket-created', handleTicketCreated);
      emitter.on('tickets:ticket-updated', handleTicketUpdated);
      emitter.on('jira:issue-status-updated', handleJiraIssueUpdated);
    });

    onUnmounted(() => {
      // Clean up WebSocket listeners
      emitter.off('tickets:ticket-created', handleTicketCreated);
      emitter.off('tickets:ticket-updated', handleTicketUpdated);
      emitter.off('jira:issue-status-updated', handleJiraIssueUpdated);
    });

    // Watch for search query changes with debounce
    let searchTimeout;
    watch(searchQuery, () => {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(() => {
        // Trigger search after 300ms delay
      }, 300);
    });

    return {
      // State
      isLoading,
      isAiLoading,
      searchQuery,
      selectedStatus,
      selectedPriority,
      selectedAgent,
      selectedCategory,
      selectedJiraStatus,
      selectedPlaneStatus,
      showDatePicker,
      isAiEnhancementEnabled,
      showAiModal,
      selectedTicketForAi,
      
      // Computed
      currentUser,
      tickets,
      isAiEnabled,
      statusOptions,
      priorityOptions,
      agentOptions,
      categoryOptions,
      jiraOptions,
      planeOptions,
      hasActiveFilters,
      filteredTickets,
      
      // Methods
      loadTickets,
      refreshTickets,
      clearFilters,
      toggleAiEnhancement,
      enhanceTicketWithAi,
      closeAiModal,
      handleAiEnhancement,
      handleTicketUpdate,
      handleTicketCreated,
    };
  },
};
</script>

<style scoped>
/* Additional styles if needed */
</style>
