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

          <!-- Feature Request Toggle -->
          <div class="flex items-center gap-2">
            <label class="flex items-center cursor-pointer">
              <input
                v-model="includeFeatureRequests"
                type="checkbox"
                class="mr-2 text-blue-600 focus:ring-blue-500 rounded"
              />
              <span class="text-sm text-n-slate-12">
                {{ $t('TICKETS.TRACKING.INCLUDE_FEATURE_REQUESTS') }}
              </span>
            </label>
          </div>

          <!-- Advanced Filters -->
          <div class="relative min-w-40">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.TRACKING.STATUS_FILTER') }}
            </label>
            <div class="relative">
              <button
                type="button"
                class="w-full px-3 py-2 border border-n-weak rounded-lg bg-white dark:bg-n-slate-1 text-left focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                @click="showStatusDropdown = !showStatusDropdown"
              >
                <span v-if="selectedStatuses.length === 0" class="text-n-slate-9">
                  {{ $t('TICKETS.TRACKING.STATUS_FILTER') }}
                </span>
                <span v-else class="text-n-slate-12">
                  {{ selectedStatuses.length }} selected
                </span>
                <Icon icon="i-lucide-chevron-down" class="absolute right-2 top-2.5 w-4 h-4" />
              </button>
              
              <div
                v-if="showStatusDropdown"
                v-on-clickaway="() => showStatusDropdown = false"
                class="absolute z-10 w-full mt-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg shadow-lg py-1 max-h-60 overflow-y-auto"
              >
                <label
                  v-for="option in statusOptions"
                  :key="option.value"
                  class="flex items-center px-3 py-2 hover:bg-n-alpha-1 cursor-pointer"
                >
                  <input
                    v-model="selectedStatuses"
                    type="checkbox"
                    :value="option.value"
                    class="mr-2 text-blue-600 focus:ring-blue-500 rounded"
                  />
                  <span class="text-sm text-n-slate-12">{{ option.label }}</span>
                </label>
              </div>
            </div>
          </div>

          <div class="relative min-w-40">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.TRACKING.PRIORITY_FILTER') }}
            </label>
            <div class="relative">
              <button
                type="button"
                class="w-full px-3 py-2 border border-n-weak rounded-lg bg-white dark:bg-n-slate-1 text-left focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                @click="showPriorityDropdown = !showPriorityDropdown"
              >
                <span v-if="selectedPriorities.length === 0" class="text-n-slate-9">
                  {{ $t('TICKETS.TRACKING.PRIORITY_FILTER') }}
                </span>
                <span v-else class="text-n-slate-12">
                  {{ selectedPriorities.length }} selected
                </span>
                <Icon icon="i-lucide-chevron-down" class="absolute right-2 top-2.5 w-4 h-4" />
              </button>
              
              <div
                v-if="showPriorityDropdown"
                v-on-clickaway="() => showPriorityDropdown = false"
                class="absolute z-10 w-full mt-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg shadow-lg py-1 max-h-60 overflow-y-auto"
              >
                <label
                  v-for="option in priorityOptions"
                  :key="option.value"
                  class="flex items-center px-3 py-2 hover:bg-n-alpha-1 cursor-pointer"
                >
                  <input
                    v-model="selectedPriorities"
                    type="checkbox"
                    :value="option.value"
                    class="mr-2 text-blue-600 focus:ring-blue-500 rounded"
                  />
                  <span class="text-sm text-n-slate-12">{{ option.label }}</span>
                </label>
              </div>
            </div>
          </div>

          <div class="relative min-w-40">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.TRACKING.AGENT_FILTER') }}
            </label>
            <div class="relative">
              <button
                type="button"
                class="w-full px-3 py-2 border border-n-weak rounded-lg bg-white dark:bg-n-slate-1 text-left focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                @click="showAgentDropdown = !showAgentDropdown"
              >
                <span v-if="selectedAgents.length === 0" class="text-n-slate-9">
                  {{ $t('TICKETS.TRACKING.AGENT_FILTER') }}
                </span>
                <span v-else class="text-n-slate-12">
                  {{ selectedAgents.length }} selected
                </span>
                <Icon icon="i-lucide-chevron-down" class="absolute right-2 top-2.5 w-4 h-4" />
              </button>
              
              <div
                v-if="showAgentDropdown"
                v-on-clickaway="() => showAgentDropdown = false"
                class="absolute z-10 w-full mt-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg shadow-lg py-1 max-h-60 overflow-y-auto"
              >
                <label
                  class="flex items-center px-3 py-2 hover:bg-n-alpha-1 cursor-pointer"
                  @click="toggleMyTickets"
                >
                  <input
                    type="checkbox"
                    :checked="selectedAgents.includes(currentUser.id)"
                    class="mr-2 text-blue-600 focus:ring-blue-500 rounded"
                  />
                  <span class="text-sm text-n-slate-12 font-medium">My Tickets</span>
                </label>
                <div class="border-t border-n-weak my-1"></div>
                <label
                  v-for="option in agentOptions"
                  :key="option.value"
                  class="flex items-center px-3 py-2 hover:bg-n-alpha-1 cursor-pointer"
                >
                  <input
                    v-model="selectedAgents"
                    type="checkbox"
                    :value="option.value"
                    class="mr-2 text-blue-600 focus:ring-blue-500 rounded"
                  />
                  <span class="text-sm text-n-slate-12">{{ option.label }}</span>
                </label>
              </div>
            </div>
          </div>

          <!-- Organization Filter -->
          <div class="relative min-w-52">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.TRACKING.ORGANIZATION_FILTER') }}
            </label>
            <div class="relative">
              <button
                type="button"
                class="w-full px-3 py-2 border border-n-weak rounded-lg bg-white dark:bg-n-slate-1 text-left focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                @click="showOrganizationDropdown = !showOrganizationDropdown"
              >
                <span v-if="selectedOrganizations.length === 0" class="text-n-slate-9">
                  {{ $t('TICKETS.TRACKING.ORGANIZATION_FILTER') }}
                </span>
                <span v-else class="text-n-slate-12">
                  {{ selectedOrganizations.length }} selected
                </span>
                <Icon icon="i-lucide-chevron-down" class="absolute right-2 top-2.5 w-4 h-4" />
              </button>
              
              <div
                v-if="showOrganizationDropdown"
                v-on-clickaway="() => showOrganizationDropdown = false"
                class="absolute z-10 w-full mt-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg shadow-lg py-1 max-h-60 overflow-y-auto"
              >
                <!-- Search Input -->
                <div class="px-3 py-2 border-b border-n-weak">
                  <NextInput
                    v-model="organizationSearchQuery"
                    :placeholder="$t('TICKETS.TRACKING.SEARCH_ORGANIZATIONS')"
                    type="search"
                    size="sm"
                  >
                    <template #leading>
                      <Icon icon="i-lucide-search" class="w-4 h-4 text-n-slate-9" />
                    </template>
                  </NextInput>
                </div>
                
                <!-- Organization Options -->
                <div v-if="filteredOrganizationOptions.length === 0" class="px-3 py-2 text-sm text-n-slate-9">
                  {{ $t('TICKETS.TRACKING.NO_ORGANIZATIONS_FOUND') }}
                </div>
                <label
                  v-for="option in filteredOrganizationOptions"
                  :key="option.value"
                  class="flex items-center px-3 py-2 hover:bg-n-alpha-1 cursor-pointer"
                >
                  <input
                    v-model="selectedOrganizations"
                    type="checkbox"
                    :value="option.value"
                    class="mr-2 text-blue-600 focus:ring-blue-500 rounded"
                  />
                  <span class="text-sm text-n-slate-12">{{ option.label }}</span>
                </label>
              </div>
            </div>
          </div>

          <!-- Category Filter -->
          <div class="relative min-w-40">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.TRACKING.CATEGORY_FILTER') }}
            </label>
            <div class="relative">
              <button
                type="button"
                class="w-full px-3 py-2 border border-n-weak rounded-lg bg-white dark:bg-n-slate-1 text-left focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                @click="showCategoryDropdown = !showCategoryDropdown"
              >
                <span v-if="selectedCategories.length === 0" class="text-n-slate-9">
                  {{ $t('TICKETS.TRACKING.CATEGORY_FILTER') }}
                </span>
                <span v-else class="text-n-slate-12">
                  {{ selectedCategories.length }} selected
                </span>
                <Icon icon="i-lucide-chevron-down" class="absolute right-2 top-2.5 w-4 h-4" />
              </button>
              
              <div
                v-if="showCategoryDropdown"
                v-on-clickaway="() => showCategoryDropdown = false"
                class="absolute z-10 w-full mt-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg shadow-lg py-1 max-h-60 overflow-y-auto"
              >
                <label
                  v-for="option in categoryOptions"
                  :key="option.value"
                  class="flex items-center px-3 py-2 hover:bg-n-alpha-1 cursor-pointer"
                >
                  <input
                    v-model="selectedCategories"
                    type="checkbox"
                    :value="option.value"
                    class="mr-2 text-blue-600 focus:ring-blue-500 rounded"
                  />
                  <span class="text-sm text-n-slate-12">{{ option.label }}</span>
                </label>
              </div>
            </div>
          </div>

          <!-- JIRA Filter -->
          <div class="relative min-w-40">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.TRACKING.JIRA_FILTER') }}
            </label>
            <div class="relative">
              <button
                type="button"
                class="w-full px-3 py-2 border border-n-weak rounded-lg bg-white dark:bg-n-slate-1 text-left focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                @click="showJiraDropdown = !showJiraDropdown"
              >
                <span v-if="selectedJiraStatus?.length === 0" class="text-n-slate-9">
                  {{ $t('TICKETS.TRACKING.JIRA_FILTER') }}
                </span>
                <span v-else class="text-n-slate-12">
                  {{ getJiraFilterLabel() }}
                </span>
                <Icon icon="i-lucide-chevron-down" class="absolute right-2 top-2.5 w-4 h-4" />
              </button>
              
              <div
                v-if="showJiraDropdown"
                v-on-clickaway="() => showJiraDropdown = false"
                class="absolute z-10 w-full mt-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg shadow-lg py-1 max-h-60 overflow-y-auto"
              >
                <label
                  v-for="option in jiraOptions"
                  :key="option.value"
                  class="flex items-center px-3 py-2 hover:bg-n-alpha-1 cursor-pointer"
                >
                  <input
                    v-model="selectedJiraStatus"
                    type="radio"
                    :value="option.value"
                    name="jira-filter"
                    class="mr-2 text-blue-600 focus:ring-blue-500"
                  />
                  <span class="text-sm text-n-slate-12">{{ option.label }}</span>
                </label>
              </div>
            </div>
          </div>

          <!-- Plane Filter -->
          <div class="relative min-w-40">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.TRACKING.PLANE_FILTER') }}
            </label>
            <div class="relative">
              <button
                type="button"
                class="w-full px-3 py-2 border border-n-weak rounded-lg bg-white dark:bg-n-slate-1 text-left focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                @click="showPlaneDropdown = !showPlaneDropdown"
              >
                <span v-if="selectedPlaneStatus?.length === 0" class="text-n-slate-9">
                  {{ $t('TICKETS.TRACKING.PLANE_FILTER') }}
                </span>
                <span v-else class="text-n-slate-12">
                  {{ getPlaneFilterLabel() }}
                </span>
                <Icon icon="i-lucide-chevron-down" class="absolute right-2 top-2.5 w-4 h-4" />
              </button>
              
              <div
                v-if="showPlaneDropdown"
                v-on-clickaway="() => showPlaneDropdown = false"
                class="absolute z-10 w-full mt-1 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg shadow-lg py-1 max-h-60 overflow-y-auto"
              >
                <label
                  v-for="option in planeOptions"
                  :key="option.value"
                  class="flex items-center px-3 py-2 hover:bg-n-alpha-1 cursor-pointer"
                >
                  <input
                    v-model="selectedPlaneStatus"
                    type="radio"
                    :value="option.value"
                    name="plane-filter"
                    class="mr-2 text-indigo-600 focus:ring-indigo-500"
                  />
                  <span class="text-sm text-n-slate-12">{{ option.label }}</span>
                </label>
              </div>
            </div>
          </div>
                    <!-- Date Range Filter -->
          <div class="relative min-w-48">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.TRACKING.DATE_RANGE') }}
            </label>
            <div class="flex gap-1">
              <NextInput
                v-model="dateRange.start"
                type="date"
                size="sm"
                :placeholder="$t('TICKETS.TRACKING.START_DATE')"
                class="flex-1"
              />
              <NextInput
                v-model="dateRange.end"
                type="date"
                size="sm"
                :placeholder="$t('TICKETS.TRACKING.END_DATE')"
                class="flex-1"
              />
            </div>
          </div>

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
              :selected-statuses="selectedStatuses"
              @ticket-click="handleTicketClick"
              @ticket-updated="handleTicketUpdate"
              @refresh="refreshTickets"
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
  },
  setup() {
    const store = useStore();
    const { t } = useI18n();
    const { accountId } = useAccount();
    
    // State
    const isLoading = ref(false);
    const searchQuery = ref('');
    const organizationSearchQuery = ref('');
    const selectedStatuses = ref([]);
    const selectedPriorities = ref([]);
    const includeFeatureRequests = ref(false);
    const selectedAgents = ref([]);
    const selectedOrganizations = ref([]);
    const selectedJiraStatus = ref('');
    const selectedPlaneStatus = ref('');
    const selectedCategories = ref([]);
    const dateRange = reactive({
      start: '',
      end: ''
    });
    const showStatusDropdown = ref(false);
    const showPriorityDropdown = ref(false);
    const showAgentDropdown = ref(false);
    const showOrganizationDropdown = ref(false);
    const showJiraDropdown = ref(false);
    const showPlaneDropdown = ref(false);
    const showCategoryDropdown = ref(false);
    const showDetailModal = ref(false);
    const selectedTicket = ref(null);
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
      { label: t('TICKETS.FILTERS.OPEN'), value: 'open' },
      { label: t('TICKETS.FILTERS.IN_PROGRESS'), value: 'in_progress' },
      { label: t('TICKETS.FILTERS.ESCALATED'), value: 'escalated' },
      { label: t('TICKETS.FILTERS.RESOLVED'), value: 'resolved' },
      { label: t('TICKETS.FILTERS.CLOSED'), value: 'closed' },
    ]);

    const priorityOptions = computed(() => [
      { label: t('TICKETS.PRIORITY.LOW'), value: 'low' },
      { label: t('TICKETS.PRIORITY.MEDIUM'), value: 'medium' },
      { label: t('TICKETS.PRIORITY.HIGH'), value: 'high' },
      { label: t('TICKETS.PRIORITY.URGENT'), value: 'urgent' },
    ]);

    const agentOptions = computed(() => {
      const agents = store.getters['agents/getAgents'];
      return agents.map(agent => ({
        label: agent.name,
        value: agent.id,
      }));
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

    const organizationOptions = ref([]);

    const filteredOrganizationOptions = computed(() => {
      if (!organizationSearchQuery.value) {
        return organizationOptions.value;
      }
      const query = organizationSearchQuery.value.toLowerCase();
      return organizationOptions.value.filter(option =>
        option.label.toLowerCase().includes(query)
      );
    });

    const hasActiveFilters = computed(() => {
      return selectedStatuses.value.length > 0 || 
             selectedPriorities.value.length > 0 || 
             selectedAgents.value.length > 0 ||
             selectedOrganizations.value.length > 0 ||
             selectedJiraStatus.value ||
             selectedPlaneStatus.value ||
             selectedCategories.value.length > 0 ||
             dateRange.start ||
             dateRange.end ||
             searchQuery.value ||
             activeQuickFilter.value !== 'my_tickets';
    });

    const getJiraFilterLabel = () => {
      const option = jiraOptions.value.find(opt => opt.value === selectedJiraStatus.value);
      return option ? option.label : t('TICKETS.TRACKING.JIRA_FILTER');
    };

    const getPlaneFilterLabel = () => {
      const option = planeOptions.value.find(opt => opt.value === selectedPlaneStatus.value);
      return option ? option.label : t('TICKETS.TRACKING.PLANE_FILTER');
    };

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
        if(query.startsWith('#')) {
          // If search starts with #, treat it as ID search
          const idQuery = query.slice(1);
          filtered = filtered.filter(ticket => ticket.id.toString().includes(idQuery));
        }else{
          filtered = filtered.filter(ticket => 
            ticket.title?.toLowerCase().includes(query) ||
            ticket.description?.toLowerCase().includes(query) ||
            ticket.id.toString().includes(query) ||
            ticket.jira_issue_key?.toLowerCase().includes(query)
        );
        }
      }
      if (selectedStatuses.value.length > 0) {
        filtered = filtered.filter(ticket => ((selectedStatuses.value.includes(ticket.status)) 
                                                                ||
                                             (selectedStatuses.value.includes('in_progress') && ticket.jira_in_progress)));
      }

      // Apply priority filter (multi-select)
      if (selectedPriorities.value.length > 0) {
        filtered = filtered.filter(ticket => selectedPriorities.value.includes(ticket.priority));
      }

      // Apply agent filter (multi-select)
      if (selectedAgents.value.length > 0) {
        filtered = filtered.filter(ticket => 
          selectedAgents.value.includes(ticket.assigned_agent?.id) ||
          (selectedAgents.value.includes(currentUser.value.id) && 
           (ticket.assigned_agent?.id === currentUser.value.id || ticket.created_by?.id === currentUser.value.id))
        );
      }

      // Apply organization filter (multi-select)
      if (selectedOrganizations.value.length > 0) {
        filtered = filtered.filter(ticket => {
          const contactOrg = ticket.contact?.organization ||
                           ticket.contact?.custom_attributes?.organization ||
                           ticket.contact?.custom_attributes?.company ||
                           ticket.contact?.additional_attributes?.company_name;
          return contactOrg && selectedOrganizations.value.includes(contactOrg);
        });
      }

      // Apply category filter (multi-select)
      if (selectedCategories.value.length > 0) {
        filtered = filtered.filter(ticket => selectedCategories.value.includes(ticket.category));
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

      // Apply date range filter
      if (dateRange.start) {
        const startDate = new Date(dateRange.start);
        filtered = filtered.filter(ticket => {
          const ticketDate = new Date(ticket.created_at);
          return ticketDate >= startDate;
        });
      }
      if (dateRange.end) {
        const endDate = new Date(dateRange.end);
        endDate.setHours(23, 59, 59, 999); // Include the entire end date
        filtered = filtered.filter(ticket => {
          const ticketDate = new Date(ticket.created_at);
          return ticketDate <= endDate;
        });
      }

      return filtered;
    });

    // Methods
    const loadTickets = async () => {
      isLoading.value = true;
      try {
        // Fetch tickets based on feature request toggle
        const apiParams = {};
        if (includeFeatureRequests.value) {
          // Show ONLY feature requests
          apiParams.is_feature_request = 'true';
        } else {
          // Show ONLY regular tickets  
          apiParams.is_feature_request = 'false';
        }
        
        await store.dispatch('tickets/fetchAllTickets', apiParams);
        updateStats();
        
        // Load organizations after tickets are loaded
        await loadOrganizations();
      } catch (error) {
        console.error('Failed to load tickets:', error);
      } finally {
        isLoading.value = false;
      }
    };

    const loadOrganizations = async () => {
      try {
        // Get all unique organizations from tickets that already have conversation data
        const allTickets = store.getters['tickets/getTickets'];
        const organizationSet = new Set();
        
        // Extract organizations from ticket data
        allTickets.forEach(ticket => {
          // Check the new organization field from contact
          if (ticket.contact?.organization) {
            organizationSet.add(ticket.contact.organization);
          }
          
          // Also check custom_attributes and additional_attributes
          if (ticket.contact?.custom_attributes?.organization) {
            organizationSet.add(ticket.contact.custom_attributes.organization);
          }
          
          if (ticket.contact?.custom_attributes?.company) {
            organizationSet.add(ticket.contact.custom_attributes.company);
          }
          
          if (ticket.contact?.additional_attributes?.company_name) {
            organizationSet.add(ticket.contact.additional_attributes.company_name);
          }
        });
        
        // Convert to options array
        organizationOptions.value = Array.from(organizationSet)
          .filter(org => org && org.trim())
          .sort()
          .map(org => ({
            label: org,
            value: org,
          }));
          
      } catch (error) {
        console.error('Failed to load organizations:', error);
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
        selectedStatuses.value = [];
        selectedPriorities.value = [];
        selectedAgents.value = [];
      }
    };

    const clearFilters = () => {
      searchQuery.value = '';
      selectedStatuses.value = [];
      selectedPriorities.value = [];
      selectedAgents.value = [];
      selectedOrganizations.value = [];
      selectedJiraStatus.value = '';
      selectedPlaneStatus.value = '';
      selectedCategories.value = [];
      dateRange.start = '';
      dateRange.end = '';
      organizationSearchQuery.value = '';
      activeQuickFilter.value = 'my_tickets';
    };

    const toggleMyTickets = () => {
      const myId = currentUser.value.id;
      if (selectedAgents.value.includes(myId)) {
        selectedAgents.value = selectedAgents.value.filter(id => id !== myId);
      } else {
        selectedAgents.value.push(myId);
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

    const handleTicketUpdate = () => {
      loadTickets();
    };

    // WebSocket event handlers
    const handleTicketUpdated = (data) => {
      console.log('TicketsWrapper: Ticket updated event received', data);
      store.dispatch('tickets/updateTicketFromWebSocket', data);
      updateStats();
    };

    const handleTicketCreated = (data) => {
      console.log('TicketsWrapper: New ticket created event received', data);
      
      // Try to add the ticket directly to the store first
      if (data && data.id) {
        console.log('TicketsWrapper: Adding ticket to store via WebSocket');
        store.dispatch('tickets/addTicket', data);
        updateStats();
        loadOrganizations(); // Reload organizations in case new one was added
      } else {
        console.log('TicketsWrapper: Incomplete WebSocket data, refreshing all tickets');
        loadTickets();
      }
    };

    const handleJiraIssueUpdated = (data) => {
      console.log('TicketsWrapper: JIRA issue updated event received', data);
      // Refresh tickets when JIRA status changes to get the latest jira_in_progress state
      loadTickets();
    };

    // Lifecycle
    onMounted(() => {
      loadTickets(); // This will also load organizations
      store.dispatch('agents/get');
      
      // Set up WebSocket listeners
      emitter.on('tickets:ticket-updated', handleTicketUpdated);
      emitter.on('tickets:ticket-created', handleTicketCreated);
      emitter.on('jira:issue-status-updated', handleJiraIssueUpdated);
    });

    onUnmounted(() => {
      emitter.off('tickets:ticket-updated', handleTicketUpdated);
      emitter.off('tickets:ticket-created', handleTicketCreated);
      emitter.off('jira:issue-status-updated', handleJiraIssueUpdated);
    });

    // Watch for ticket changes to update stats
    watch(tickets, updateStats, { deep: true });

    // Watch for feature request toggle changes
    watch(includeFeatureRequests, () => {
      loadTickets();
    });

    return {
      // State
      isLoading,
      searchQuery,
      organizationSearchQuery,
      selectedStatuses,
      selectedPriorities,
      includeFeatureRequests,
      selectedAgents,
      selectedOrganizations,
      selectedJiraStatus,
      selectedPlaneStatus,
      selectedCategories,
      dateRange,
      showStatusDropdown,
      showPriorityDropdown,
      showAgentDropdown,
      showOrganizationDropdown,
      showJiraDropdown,
      showPlaneDropdown,
      showCategoryDropdown,
      showDetailModal,
      selectedTicket,
      viewMode,
      activeQuickFilter,
      ticketStats,
      
      // Computed
      currentUser,
      tickets,
      quickFilters,
      statusOptions,
      priorityOptions,
      agentOptions,
      jiraOptions,
      planeOptions,
      categoryOptions,
      organizationOptions,
      filteredOrganizationOptions,
      hasActiveFilters,
      filteredTickets,
      
      // Methods
      loadTickets,
      loadOrganizations,
      refreshTickets,
      applyQuickFilter,
      clearFilters,
      toggleMyTickets,
      getJiraFilterLabel,
      getPlaneFilterLabel,
      handleTicketClick,
      closeDetailModal,
      handleTicketUpdate,
    };
  },
};
</script>

<style scoped>
/* Additional styles for the comprehensive wrapper */
</style>
