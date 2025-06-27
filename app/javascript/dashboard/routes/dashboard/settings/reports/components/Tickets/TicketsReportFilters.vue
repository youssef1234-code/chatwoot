<script>
import endOfDay from 'date-fns/endOfDay';
import getUnixTime from 'date-fns/getUnixTime';
import startOfDay from 'date-fns/startOfDay';
import subDays from 'date-fns/subDays';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import WootDateRangePicker from 'dashboard/components/ui/DateRangePicker.vue';

const CUSTOM_DATE_RANGE_ID = 5;

export default {
  components: {
    WootDateRangePicker,
    Thumbnail,
  },
  props: {
    ticketCategories: {
      type: Array,
      default: () => [],
    },
  },
  emits: ['filter-change'],
  data() {
    return {
      currentDateRangeSelection: {
        id: 0,
        name: this.$t('REPORT.DATE_RANGE_OPTIONS.LAST_7_DAYS'),
      },
      customDateRange: [new Date(), new Date()],
      businessHoursSelected: false,
      selectedFilters: {
        status: null,
        priority: null,
        assigned_agent_id: null,
        linked_with_jira: null,
        jira_status: null,
        category: null,
      },
    };
  },
  computed: {
    dateRange() {
      return [
        { id: 0, name: this.$t('REPORT.DATE_RANGE_OPTIONS.LAST_7_DAYS') },
        { id: 1, name: this.$t('REPORT.DATE_RANGE_OPTIONS.LAST_30_DAYS') },
        { id: 2, name: this.$t('REPORT.DATE_RANGE_OPTIONS.LAST_3_MONTHS') },
        { id: 3, name: this.$t('REPORT.DATE_RANGE_OPTIONS.LAST_6_MONTHS') },
        { id: 4, name: this.$t('REPORT.DATE_RANGE_OPTIONS.LAST_YEAR') },
        { id: 5, name: this.$t('REPORT.DATE_RANGE_OPTIONS.CUSTOM_DATE_RANGE') },
      ];
    },
    currentAccount(){
      const accountId = this.$store.getters.getCurrentAccountId;
      const accountFromAccountsStore =
        this.$store.getters["accounts/getAccount"](accountId);
      if (
        accountFromAccountsStore &&
        Object.keys(accountFromAccountsStore).length > 0
      ) {
        return accountFromAccountsStore;
      }
    },
    loadCategories() {
      return  this.currentAccount?.settings?.ticket_categories;
    },
    isDateRangeSelected() {
      return this.currentDateRangeSelection.id === CUSTOM_DATE_RANGE_ID;
    },
    to() {
      if (this.isDateRangeSelected) {
        return this.toCustomDate(this.customDateRange[1]);
      }
      return this.toCustomDate(new Date());
    },
    from() {
      if (this.isDateRangeSelected) {
        return this.fromCustomDate(this.customDateRange[0]);
      }
      const dateRange = {
        0: 6,
        1: 29,
        2: 89,
        3: 179,
        4: 364,
      };
      const diff = dateRange[this.currentDateRangeSelection.id];
      const fromDate = subDays(new Date(), diff);
      return this.fromCustomDate(fromDate);
    },
    agents() {
      return this.$store.getters['agents/getAgents'] || [];
    },
    statusOptions() {
      return [
        { id: 'open', name: this.$t('TICKETS_REPORTS.STATUS.OPEN') },
        { id: 'in_progress', name: this.$t('TICKETS_REPORTS.STATUS.IN_PROGRESS') },
        { id: 'escalated', name: this.$t('TICKETS_REPORTS.STATUS.ESCALATED') },
        { id: 'resolved', name: this.$t('TICKETS_REPORTS.STATUS.RESOLVED') },
        { id: 'closed', name: this.$t('TICKETS_REPORTS.STATUS.CLOSED') },
      ];
    },
    priorityOptions() {
      return [
        { id: 'low', name: this.$t('TICKETS_REPORTS.PRIORITY.LOW') },
        { id: 'medium', name: this.$t('TICKETS_REPORTS.PRIORITY.MEDIUM') },
        { id: 'high', name: this.$t('TICKETS_REPORTS.PRIORITY.HIGH') },
        { id: 'urgent', name: this.$t('TICKETS_REPORTS.PRIORITY.URGENT') },
      ];
    },
    categoryOptions() {
      // Use categories from account settings (loadCategories is a computed property, not a function)
      let categories = this.loadCategories || [];
      console.log('CATEGORIES: ' , categories);
      
      // If no categories from account settings, try to get from current account getter
      if (!categories || categories.length === 0) {
        const currentAccount = this.$store.getters.getCurrentAccount;
        categories = currentAccount?.settings?.ticket_categories || [];
      }
      
      if (categories.length > 0) {
        return categories.map(category => ({ 
          id: typeof category === 'string' ? category : category.name || category.id, 
          name: typeof category === 'string' ? category : category.name || category.id 
        }));
      }
      
      // Default categories if none configured
      return [
        { id: 'Bug', name: this.$t('TICKETS_REPORTS.CATEGORY.BUG') },
        { id: 'Feature Request', name: this.$t('TICKETS_REPORTS.CATEGORY.FEATURE_REQUEST') },
        { id: 'Support', name: this.$t('TICKETS_REPORTS.CATEGORY.SUPPORT') },
        { id: 'Technical Issue', name: this.$t('TICKETS_REPORTS.CATEGORY.TECHNICAL_ISSUE') },
        { id: 'Billing', name: this.$t('TICKETS_REPORTS.CATEGORY.BILLING') },
        { id: 'Integration', name: this.$t('TICKETS_REPORTS.CATEGORY.INTEGRATION') },
      ];
    },
    jiraLinkOptions() {
      return [
        { id: 'true', name: this.$t('TICKETS_REPORTS.JIRA_LINK.LINKED') },
        { id: 'false', name: this.$t('TICKETS_REPORTS.JIRA_LINK.NOT_LINKED') },
      ];
    },
    jiraStatusOptions() {
      return [
        { id: 'escalated', name: this.$t('TICKETS_REPORTS.JIRA_STATUS.ESCALATED') },
        { id: 'in_progress', name: this.$t('TICKETS_REPORTS.JIRA_STATUS.IN_PROGRESS') },
        { id: 'done', name: this.$t('TICKETS_REPORTS.JIRA_STATUS.DONE') },
      ];
    },
    showJiraStatusFilter() {
      return this.selectedFilters.linked_with_jira === 'true';
    },
  },
  mounted() {
    this.onDateRangeChange();
  },
  methods: {
    onDateRangeChange() {
      this.emitFilterChange();
    },
    onCustomDateRangeChange(value) {
      this.customDateRange = value;
      this.emitFilterChange();
    },
    onBusinessHoursToggle() {
      this.businessHoursSelected = !this.businessHoursSelected;
      this.emitFilterChange();
    },
    onFilterOptionChange() {
      // Reset JIRA status if linked_with_jira is changed to false or null
      if (this.selectedFilters.linked_with_jira !== 'true') {
        this.selectedFilters.jira_status = null;
      }
      this.emitFilterChange();
    },
    emitFilterChange() {
      this.$emit('filter-change', {
        from: this.from,
        to: this.to,
        businessHours: this.businessHoursSelected,
        ...this.selectedFilters,
      });
    },
    fromCustomDate(date) {
      return getUnixTime(startOfDay(date));
    },
    toCustomDate(date) {
      return getUnixTime(endOfDay(date));
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-6 p-6 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2">
    <div class="flex flex-col gap-4">
      <h3 class="text-lg font-medium text-n-slate-12">
        {{ $t('TICKETS_REPORTS.FILTERS.TITLE') }}
      </h3>
      
      <!-- Date Range and Business Hours -->
      <div class="flex flex-col md:flex-row gap-4">
        <div class="flex-1">
          <label class="block text-sm font-medium text-n-slate-11 mb-2">
            {{ $t('REPORT.DURATION_FILTER_LABEL') }}
          </label>
          <select
            v-model="currentDateRangeSelection"
            class="w-full px-3 py-2 border border-n-weak rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 bg-n-solid-3 text-n-slate-12"
            @change="onDateRangeChange"
          >
            <option v-for="range in dateRange" :key="range.id" :value="range">
              {{ range.name }}
            </option>
          </select>
        </div>
        
        <div v-if="isDateRangeSelected" class="flex-1">
          <label class="block text-sm font-medium text-n-slate-11 mb-2">
            {{ $t('REPORT.CUSTOM_DATE_RANGE.PLACEHOLDER') }}
          </label>
          <WootDateRangePicker
            :value="customDateRange"
            :confirm-text="$t('REPORT.CUSTOM_DATE_RANGE.CONFIRM')"
            :placeholder="$t('REPORT.CUSTOM_DATE_RANGE.PLACEHOLDER')"
            @change="onCustomDateRangeChange"
          />
        </div>
        
        <div class="flex items-end">
          <label class="flex items-center space-x-2 text-sm">
            <input
              v-model="businessHoursSelected"
              type="checkbox"
              class="rounded border-n-weak text-woot-500 focus:ring-woot-500"
              @change="onBusinessHoursToggle"
            />
            <span class="text-n-slate-11">{{ $t('REPORT.BUSINESS_HOURS') }}</span>
          </label>
        </div>
      </div>
    </div>

    <!-- Filter Options -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
      <!-- Status Filter -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-2">
          {{ $t('TICKETS_REPORTS.FILTERS.STATUS') }}
        </label>
        <select
          v-model="selectedFilters.status"
          class="w-full px-3 py-2 border border-n-weak rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 bg-n-solid-3 text-n-slate-12"
          @change="onFilterOptionChange"
        >
          <option :value="null">{{ $t('TICKETS_REPORTS.FILTERS.ALL_STATUSES') }}</option>
          <option v-for="status in statusOptions" :key="status.id" :value="status.id">
            {{ status.name }}
          </option>
        </select>
      </div>

      <!-- Priority Filter -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-2">
          {{ $t('TICKETS_REPORTS.FILTERS.PRIORITY') }}
        </label>
        <select
          v-model="selectedFilters.priority"
          class="w-full px-3 py-2 border border-n-weak rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 bg-n-solid-3 text-n-slate-12"
          @change="onFilterOptionChange"
        >
          <option :value="null">{{ $t('TICKETS_REPORTS.FILTERS.ALL_PRIORITIES') }}</option>
          <option v-for="priority in priorityOptions" :key="priority.id" :value="priority.id">
            {{ priority.name }}
          </option>
        </select>
      </div>

      <!-- Category Filter -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-2">
          {{ $t('TICKETS_REPORTS.FILTERS.CATEGORY') }}
        </label>
        <select
          v-model="selectedFilters.category"
          class="w-full px-3 py-2 border border-n-weak rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 bg-n-solid-3 text-n-slate-12"
          @change="onFilterOptionChange"
        >
          <option :value="null">{{ $t('TICKETS_REPORTS.FILTERS.ALL_CATEGORIES') }}</option>
          <option v-for="category in categoryOptions" :key="category.id" :value="category.id">
            {{ category.name }}
          </option>
        </select>
      </div>

      <!-- Agent Filter -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-2">
          {{ $t('TICKETS_REPORTS.FILTERS.AGENT') }}
        </label>
        <select
          v-model="selectedFilters.assigned_agent_id"
          class="w-full px-3 py-2 border border-n-weak rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 bg-n-solid-3 text-n-slate-12"
          @change="onFilterOptionChange"
        >
          <option :value="null">{{ $t('TICKETS_REPORTS.FILTERS.ALL_AGENTS') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </div>

      <!-- Linked with JIRA Filter -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-2">
          {{ $t('TICKETS_REPORTS.FILTERS.LINKED_WITH_JIRA') }}
        </label>
        <select
          v-model="selectedFilters.linked_with_jira"
          class="w-full px-3 py-2 border border-n-weak rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 bg-n-solid-3 text-n-slate-12"
          @change="onFilterOptionChange"
        >
          <option :value="null">{{ $t('TICKETS_REPORTS.FILTERS.ALL') }}</option>
          <option v-for="option in jiraLinkOptions" :key="option.id" :value="option.id">
            {{ option.name }}
          </option>
        </select>
      </div>

      <!-- JIRA Status Filter (only show when linked with JIRA) -->
      <div v-if="showJiraStatusFilter">
        <label class="block text-sm font-medium text-n-slate-11 mb-2">
          {{ $t('TICKETS_REPORTS.FILTERS.JIRA_STATUS') }}
        </label>
        <select
          v-model="selectedFilters.jira_status"
          class="w-full px-3 py-2 border border-n-weak rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 bg-n-solid-3 text-n-slate-12"
          @change="onFilterOptionChange"
        >
          <option :value="null">{{ $t('TICKETS_REPORTS.FILTERS.ALL_JIRA_STATUSES') }}</option>
          <option v-for="jiraStatus in jiraStatusOptions" :key="jiraStatus.id" :value="jiraStatus.id">
            {{ jiraStatus.name }}
          </option>
        </select>
      </div>
    </div>
  </div>
</template>
