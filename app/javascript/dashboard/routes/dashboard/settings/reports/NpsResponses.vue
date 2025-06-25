<script>
import { mapGetters } from 'vuex';
import { useAlert, useTrack } from 'dashboard/composables';
import NpsMetrics from './components/NpsMetrics.vue';
import NpsTable from './components/NpsTable.vue';
import ReportFilterSelector from './components/FilterSelector.vue';
import { generateFileName } from '../../../../helper/downloadHelper';
import { REPORTS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import { FEATURE_FLAGS } from '../../../../featureFlags';
import V4Button from 'dashboard/components-next/button/Button.vue';
import ReportHeader from './components/ReportHeader.vue';

export default {
  name: 'NpsResponses',
  components: {
    NpsMetrics,
    NpsTable,
    ReportFilterSelector,
    ReportHeader,
    V4Button,
  },
  data() {
    return {
      pageIndex: 0,
      from: 0,
      to: 0,
      userIds: [],
      inbox: null,
      team: null,
      rating: null,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      uiFlags: 'nps/getUIFlags',
      isFeatureEnabledOnAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    requestPayload() {
      return {
        from: this.from,
        to: this.to,
        user_ids: this.userIds,
        inbox_id: this.inbox,
        team_id: this.team,
        rating: this.rating,
      };
    },
    isTeamsEnabled() {
      return this.isFeatureEnabledOnAccount(
        this.accountId,
        FEATURE_FLAGS.TEAM_MANAGEMENT
      );
    },
  },
  mounted() {
    this.getAllData();
  },
  methods: {
    getAllData() {
      try {
        this.$store.dispatch('nps/getMetrics', this.requestPayload);
        this.getResponses();
      } catch {
        useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
      }
    },
    getResponses() {
      this.$store.dispatch('nps/get', {
        page: this.pageIndex + 1,
        ...this.requestPayload,
      });
    },
    downloadReports() {
      const type = 'nps';
      try {
        this.$store.dispatch('nps/downloadNPSReports', {
          fileName: generateFileName({ type, to: this.to }),
          ...this.requestPayload,
        });
        useTrack(REPORTS_EVENTS.DOWNLOAD_REPORT, { reportType: type });
        useAlert(this.$t('REPORT.DOWNLOAD_INITIATED'));
      } catch {
        useAlert(this.$t('REPORT.DOWNLOAD_FAILED'));
      }
    },
    onFilterChange({
      from,
      to,
      selectedAgents,
      selectedInbox,
      selectedTeam,
      selectedRating,
    }) {
      // do not track filter change on initial load
      if (this.from !== 0 && this.to !== 0) {
        useTrack(REPORTS_EVENTS.FILTER_REPORT, {
          filterType: 'date',
          reportType: 'nps',
        });
      }

      this.from = from;
      this.to = to;
      this.userIds = selectedAgents.map(el => el.id);
      this.inbox = selectedInbox?.id;
      this.team = selectedTeam?.id;
      this.rating = selectedRating?.value;

      this.getAllData();
    },
    onPageNumberChange(pageIndex) {
      this.pageIndex = pageIndex;
      this.getResponses();
    },
  },
};
</script>

<template>
  <div>
    <ReportHeader :header-title="$t('NPS_REPORTS.HEADER')">
      <V4Button
        :label="$t('NPS_REPORTS.DOWNLOAD')"
        icon="i-ph-download-simple"
        size="sm"
        @click="downloadReports"
      />
    </ReportHeader>

    <div class="flex flex-col gap-4">
      <ReportFilterSelector
        show-agents-filter
        show-inbox-filter
        show-rating-filter
        rating-type="nps"
        :show-team-filter="isTeamsEnabled"
        :show-business-hours-switch="false"
        @filter-change="onFilterChange"
      />
      <NpsMetrics :filters="requestPayload" />
      <NpsTable
        :page-index="pageIndex"
        @page-change="onPageNumberChange"
      />
    </div>
  </div>
</template>
