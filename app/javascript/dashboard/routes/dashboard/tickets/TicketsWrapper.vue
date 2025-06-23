<template>
  <div class="flex flex-col w-full h-full m-0 p-6 sm:py-8 lg:px-16 overflow-auto bg-n-background font-inter">
    <div class="flex flex-col w-full max-w-full mx-auto">
      <!-- Header with Stats -->
      <div class="bg-white dark:bg-n-slate-1 border border-n-weak p-6 rounded-lg mb-6">
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
            <!-- Stats Summary -->
            <div class="flex items-center gap-4 mr-6">
              <div class="text-center">
                <div class="text-2xl font-bold text-blue-600">{{ ticketStats.total }}</div>
                <div class="text-xs text-n-slate-9">Total</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold text-yellow-600">{{ ticketStats.open }}</div>
                <div class="text-xs text-n-slate-9">Open</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold text-green-600">{{ ticketStats.resolved }}</div>
                <div class="text-xs text-n-slate-9">Resolved</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold text-orange-600">{{ ticketStats.escalated }}</div>
                <div class="text-xs text-n-slate-9">JIRA</div>
              </div>
            </div>
            
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
            </NextButton>
          </div>
        </div>
      </div>

      <!-- Advanced Filters -->
      <div class="bg-white dark:bg-n-slate-1 border border-n-weak p-4 rounded-lg mb-6">
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

          <!-- Quick Filter Buttons -->
          <div class="flex items-center gap-2">
            <NextButton
              v-for="filter in quickFilters"
              :key="filter.key"
              :variant="activeQuickFilter === filter.key ? 'solid' : 'outline'"
              size="sm"
              @click="applyQuickFilter(filter.key)"
            >
              {{ filter.label }}
            </NextButton>
          </div>

          <!-- Advanced Filters -->
          <NextSelect
            v-model="selectedStatus"
            :label="$t('TICKETS.TRACKING.STATUS_FILTER')"
            name="status"
            :options="statusOptions"
            :placeholder="$t('TICKETS.TRACKING.STATUS_FILTER')"
            class="min-w-40"
          />

          <NextSelect
            v-model="selectedPriority"
            :label="$t('TICKETS.TRACKING.PRIORITY_FILTER')"
            name="priority"
            :options="priorityOptions"
            :placeholder="$t('TICKETS.TRACKING.PRIORITY_FILTER')"
            class="min-w-40"
          />

          <NextSelect
            v-model="selectedAgent"
            :label="$t('TICKETS.TRACKING.AGENT_FILTER')"
            name="agent"
            :options="agentOptions"
            :placeholder="$t('TICKETS.TRACKING.AGENT_FILTER')"
            class="min-w-40"
          />

          <!-- Clear Filters -->
          <NextButton
            v-if="hasActiveFilters"
            variant="ghost"
            size="sm"
            color="ruby"
            @click="clearFilters"
          >
            {{ $t('TICKETS.TRACKING.CLEAR_FILTERS') }}
          </NextButton>
        </div>
      </div>

      <!-- Main Content Area -->
      <div class="flex-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg overflow-hidden">
        <!-- View Toggle -->
        <div class="border-b border-n-weak p-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <NextButton
                :variant="viewMode === 'kanban' ? 'solid' : 'outline'"
                size="sm"
                @click="viewMode = 'kanban'"
              >
                <Icon icon="i-lucide-columns" class="w-4 h-4 mr-2" />
                {{ $t('TICKETS.VIEW.KANBAN') }}
              </NextButton>
              <NextButton
                :variant="viewMode === 'list' ? 'solid' : 'outline'"
                size="sm"
                @click="viewMode = 'list'"
              >
                <Icon icon="i-lucide-list" class="w-4 h-4 mr-2" />
                {{ $t('TICKETS.VIEW.LIST') }}
              </NextButton>
            </div>
            
            <div class="text-sm text-n-slate-9">
              {{ filteredTickets.length }} {{ $t('TICKETS.TICKETS_FOUND') }}
            </div>
          </div>
        </div>

        <!-- Content -->
        <div class="h-full overflow-hidden">
          <div v-if="!currentUser" class="flex items-center justify-center h-full">
            <div class="animate-pulse">Loading...</div>
          </div>
          
          <template v-else>
            <!-- Kanban View -->
            <TicketsKanbanBoard
              v-show="viewMode === 'kanban'"
              key="kanban"
              :tickets="filteredTickets"
              :is-loading="isLoading"
              :current-user="currentUser"
              :is-ai-enhancement-enabled="isAiEnhancementEnabled"
              @ticket-click="handleTicketClick"
              @ticket-updated="handleTicketUpdate"
              @refresh="refreshTickets"
              @enhance-with-ai="enhanceTicketWithAi"
            />
            
            <!-- List View -->
            <TicketsListView
              v-show="viewMode === 'list'"
              key="list"
              :tickets="filteredTickets"
              :is-loading="isLoading"
              :current-user="currentUser"
              @ticket-click="handleTicketClick"
              @ticket-updated="handleTicketUpdate"
              @enhance-with-ai="enhanceTicketWithAi"
            />
          </template>
        </div>
      </div>

      <!-- Modals -->
      <TicketDetailModal
        v-if="showDetailModal"
        :ticket="selectedTicket"
        :current-user="currentUser"
        @close="closeDetailModal"
        @updated="handleTicketUpdate"
        @refresh="refreshTickets"
      />

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
import { computed, ref, onMounted, onUnmounted, watch, reactive } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';

import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextSelect from 'v3/components/Form/Select.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

import TicketsKanbanBoard from './components/TicketsKanbanBoard.vue';
import TicketsListView from './components/TicketsListView.vue';
import TicketDetailModal from './components/TicketDetailModal.vue';
import AiEnhancementModal from './components/AiEnhancementModal.vue';

import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import TicketsAPI from 'dashboard/api/tickets';

export default {
  name: 'TicketsWrapper',
  components: {
    NextButton,
    NextInput,
    NextSelect,
    Icon,
    TicketsKanbanBoard,
    TicketsListView,
    TicketDetailModal,
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
    const isAiEnhancementEnabled = ref(false);
    const showDetailModal = ref(false);
    const showAiModal = ref(false);
    const selectedTicket = ref(null);
    const selectedTicketForAi = ref(null);
    const viewMode = ref('kanban');
    const activeQuickFilter = ref('my_tickets');
    
    // Stats
    const ticketStats = reactive({
      total: 0,
      open: 0,
      resolved: 0,
      escalated: 0,
    });

    // Computed
    const currentUser = computed(() => store.getters.getCurrentUser);
    const tickets = computed(() => store.getters['tickets/getTickets']);
    const isAiEnabled = true; // Could be from settings

    const quickFilters = computed(() => [
      { key: 'my_tickets', label: t('TICKETS.FILTERS.MY_TICKETS') },
      { key: 'open', label: t('TICKETS.FILTERS.OPEN') },
      { key: 'urgent', label: t('TICKETS.FILTERS.URGENT') },
      { key: 'escalated', label: t('TICKETS.FILTERS.ESCALATED') },
      { key: 'all', label: t('TICKETS.FILTERS.ALL') },
    ]);

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

    const hasActiveFilters = computed(() => {
      return selectedStatus.value || selectedPriority.value || selectedAgent.value || searchQuery.value || activeQuickFilter.value !== 'my_tickets';
    });

    const filteredTickets = computed(() => {
      let filtered = [...tickets.value];

      // Apply quick filter first
      if (activeQuickFilter.value === 'my_tickets') {
        filtered = filtered.filter(ticket => 
          ticket.assigned_agent?.id === currentUser.value.id ||
          ticket.created_by?.id === currentUser.value.id
        );
      } else if (activeQuickFilter.value === 'open') {
        filtered = filtered.filter(ticket => ticket.status === 'open');
      } else if (activeQuickFilter.value === 'urgent') {
        filtered = filtered.filter(ticket => ticket.priority === 'urgent');
      } else if (activeQuickFilter.value === 'escalated') {
        filtered = filtered.filter(ticket => ticket.status === 'escalated');
      }

      // Apply search filter
      if (searchQuery.value) {
        const query = searchQuery.value.toLowerCase();
        filtered = filtered.filter(ticket => 
          ticket.title?.toLowerCase().includes(query) ||
          ticket.description?.toLowerCase().includes(query) ||
          ticket.id.toString().includes(query) ||
          ticket.jira_issue_key?.toLowerCase().includes(query)
        );
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
        filtered = filtered.filter(ticket => ticket.assigned_agent?.id === selectedAgent.value);
      }

      return filtered;
    });

    // Methods
    const loadTickets = async () => {
      isLoading.value = true;
      try {
        const params = {};
        await store.dispatch('tickets/fetchTickets', params);
        updateStats();
      } catch (error) {
        console.error('Failed to load tickets:', error);
        useAlert(t('TICKETS.TRACKING.LOAD_ERROR'));
      } finally {
        isLoading.value = false;
      }
    };

    const updateStats = () => {
      const allTickets = tickets.value;
      ticketStats.total = allTickets.length;
      ticketStats.open = allTickets.filter(t => t.status === 'open' || t.status === 'in_progress').length;
      ticketStats.resolved = allTickets.filter(t => t.status === 'resolved' || t.status === 'closed').length;
      ticketStats.escalated = allTickets.filter(t => t.status === 'escalated' || t.jira_issue_key).length;
    };

    const refreshTickets = async () => {
      await loadTickets();
      useAlert(t('TICKETS.TRACKING.REFRESHED'));
    };

    const applyQuickFilter = (filterKey) => {
      activeQuickFilter.value = filterKey;
      // Clear other filters when applying quick filter
      if (filterKey !== 'all') {
        selectedStatus.value = '';
        selectedPriority.value = '';
        selectedAgent.value = '';
      }
    };

    const clearFilters = () => {
      searchQuery.value = '';
      selectedStatus.value = '';
      selectedPriority.value = '';
      selectedAgent.value = '';
      activeQuickFilter.value = 'my_tickets';
    };

    const toggleAiEnhancement = async () => {
      if (!isAiEnhancementEnabled.value) {
        isAiLoading.value = true;
        try {
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

    const handleTicketClick = (ticket) => {
      selectedTicket.value = ticket;
      showDetailModal.value = true;
    };

    const closeDetailModal = () => {
      showDetailModal.value = false;
      selectedTicket.value = null;
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
      loadTickets();
    };

    // WebSocket event handlers
    const handleTicketUpdated = (data) => {
      store.dispatch('tickets/updateTicketFromWebSocket', data);
      updateStats();
    };

    const handleJiraIssueUpdated = (data) => {
      loadTickets();
    };

    // Lifecycle
    onMounted(() => {
      loadTickets();
      store.dispatch('agents/get');
      
      // Set up WebSocket listeners
      emitter.on('tickets:ticket-updated', handleTicketUpdated);
      emitter.on('jira:issue-status-updated', handleJiraIssueUpdated);
    });

    onUnmounted(() => {
      emitter.off('tickets:ticket-updated', handleTicketUpdated);
      emitter.off('jira:issue-status-updated', handleJiraIssueUpdated);
    });

    // Watch for ticket changes to update stats
    watch(tickets, updateStats, { deep: true });

    return {
      // State
      isLoading,
      isAiLoading,
      searchQuery,
      selectedStatus,
      selectedPriority,
      selectedAgent,
      isAiEnhancementEnabled,
      showDetailModal,
      showAiModal,
      selectedTicket,
      selectedTicketForAi,
      viewMode,
      activeQuickFilter,
      ticketStats,
      
      // Computed
      currentUser,
      tickets,
      isAiEnabled,
      quickFilters,
      statusOptions,
      priorityOptions,
      agentOptions,
      hasActiveFilters,
      filteredTickets,
      
      // Methods
      loadTickets,
      refreshTickets,
      applyQuickFilter,
      clearFilters,
      toggleAiEnhancement,
      handleTicketClick,
      closeDetailModal,
      enhanceTicketWithAi,
      closeAiModal,
      handleAiEnhancement,
      handleTicketUpdate,
    };
  },
};
</script>

<style scoped>
/* Additional styles for the comprehensive wrapper */
</style>
