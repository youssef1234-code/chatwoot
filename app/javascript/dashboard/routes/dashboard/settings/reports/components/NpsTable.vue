<script setup>
import { defineEmits, computed, h } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

// [TODO] Instead of converting the values to their reprentation when building the tableData
// We should do the change in the cell
import { messageStamp, dynamicTime } from 'shared/helpers/timeHelper';

// components
import Table from 'dashboard/components/table/Table.vue';
import Pagination from 'dashboard/components/table/Pagination.vue';
import UserAvatarWithName from 'dashboard/components/widgets/UserAvatarWithName.vue';
import ConversationCell from './ConversationCell.vue';

// constants
import { NPS_RATINGS } from 'shared/constants/messages';

import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
} from '@tanstack/vue-table';

const { pageIndex } = defineProps({
  pageIndex: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(['pageChange']);
const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const npsResponses = useMapGetter('nps/getNPSResponses');
const metrics = useMapGetter('nps/getMetrics');

const tableData = computed(() => {
  if (!npsResponses.value || !Array.isArray(npsResponses.value)) {
    return [];
  }
  
  return npsResponses.value.map(response => ({
    contact: response.contact,
    assignedAgent: response.assigned_agent,
    rating: response.rating,
    feedbackText: response.feedback_message || '---',
    conversationId: response.conversation_id,
    createdAgo: dynamicTime(response.created_at),
    createdAt: messageStamp(response.created_at, 'LLL d yyyy, h:mm a'),
  }));
});

const defaultSpanRender = cellProps => {
  const value = cellProps.getValue() || '---';
  return h(
    'span',
    {
      class: 'line-clamp-5 break-words max-w-full text-n-slate-12',
      title: value,
    },
    value
  );
};

const columnHelper = createColumnHelper();

const columns = [
  columnHelper.accessor('contact', {
    header: t('NPS_REPORTS.TABLE.HEADER.CONTACT_NAME'),
    width: 200,
    cell: cellProps => {
      const { contact } = cellProps.row.original;
      if (contact) {
        return h(UserAvatarWithName, {
          user: contact,
          class: 'max-w-[200px] overflow-hidden',
        });
      }
      return '--';
    },
  }),
  columnHelper.accessor('assignedAgent', {
    header: t('NPS_REPORTS.TABLE.HEADER.AGENT_NAME'),
    width: 200,
    cell: cellProps => {
      const { assignedAgent } = cellProps.row.original;
      if (assignedAgent) {
        return h(UserAvatarWithName, {
          user: assignedAgent,
          class: 'max-w-[200px] overflow-hidden',
        });
      }
      return '--';
    },
  }),
  columnHelper.accessor('rating', {
    header: t('NPS_REPORTS.TABLE.HEADER.RATING'),
    cell: cellProps => {
      const rating = cellProps.getValue();
      return h(
        'div',
        {
          class: `inline-flex items-center justify-center w-8 h-8 rounded text-white text-sm font-medium ${
            rating >= 0 && rating <= 6 ? 'bg-red-500' :
            rating >= 7 && rating <= 8 ? 'bg-yellow-500' : 
            'bg-green-500'
          }`,
        },
        rating
      );
    },
    width: 120,
  }),
  columnHelper.accessor('feedbackText', {
    header: t('NPS_REPORTS.TABLE.HEADER.FEEDBACK_TEXT'),
    cell: defaultSpanRender,
    width: 250,
  }),
  columnHelper.accessor('conversationId', {
    header: t('NPS_REPORTS.TABLE.HEADER.CONVERSATION_ID'),
    cell: cellProps => h(ConversationCell, { row: cellProps.row }),
    width: 160,
  }),
  columnHelper.accessor('createdAt', {
    header: t('NPS_REPORTS.TABLE.HEADER.CREATED_AT'),
    cell: cellProps => {
      const { createdAt, createdAgo } = cellProps.row.original;
      return h('div', {}, [
        h(
          'div',
          {
            class: 'text-n-slate-12 text-sm',
          },
          createdAgo
        ),
        h(
          'div',
          {
            class: 'text-n-slate-10 text-xs',
          },
          createdAt
        ),
      ]);
    },
    width: 200,
  }),
];

const paginationParams = computed(() => {
  return {
    pageIndex: pageIndex,
    pageSize: 25,
  };
});

const table = useVueTable({
  get data() {
    return tableData.value;
  },
  columns,
  manualPagination: true,
  enableSorting: false,
  getCoreRowModel: getCoreRowModel(),
  get rowCount() {
    return metrics.value.totalResponseCount;
  },
  state: {
    get pagination() {
      return paginationParams.value;
    },
  },
  onPaginationChange: updater => {
    const newPagination = updater(paginationParams.value);
    emit('pageChange', newPagination.pageIndex);
  },
});
</script>

<template>
  <div
    class="shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-5"
  >
    <Table
      :table="table"
      class="max-h-[calc(100vh-21.875rem)]"
    />
    <div
      v-if="!tableData.length"
      class="h-48 flex items-center justify-center text-n-slate-12 text-sm"
    >
      {{ $t('NPS_REPORTS.NO_RECORDS') }}
    </div>
    <div
      v-if="metrics.totalResponseCount"
      class="table-pagination"
    >
      <Pagination
        class="mt-2"
        :table="table"
      />
    </div>
  </div>
</template>
