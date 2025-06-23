<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { formatDate } from 'shared/helpers/DateHelper';

const props = defineProps({
  ticket: {
    type: Object,
    required: true,
  },
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['refresh']);

const { t } = useI18n();
const store = useStore();
const isUpdating = ref(false);

const ticketTitle = computed(() => props.ticket.title || 'Untitled Ticket');
const ticketDescription = computed(() => props.ticket.description || '');
const ticketStatus = computed(() => props.ticket.status || 'open');
const ticketPriority = computed(() => props.ticket.priority || 'medium');
const createdAt = computed(() => {
  if (props.ticket.created_at) {
    return formatDate(new Date(props.ticket.created_at), 'MMM dd, yyyy');
  }
  return '';
});

const getStatusColor = (status) => {
  const colors = {
    open: 'bg-blue-50 text-blue-700 border-blue-200',
    in_progress: 'bg-yellow-50 text-yellow-700 border-yellow-200',
    resolved: 'bg-green-50 text-green-700 border-green-200',
    closed: 'bg-gray-50 text-gray-700 border-gray-200',
  };
  return colors[status] || colors.open;
};

const getPriorityColor = (priority) => {
  const colors = {
    low: 'bg-gray-50 text-gray-700 border-gray-200',
    medium: 'bg-blue-50 text-blue-700 border-blue-200',
    high: 'bg-orange-50 text-orange-700 border-orange-200',
    urgent: 'bg-red-50 text-red-700 border-red-200',
  };
  return colors[priority] || colors.medium;
};

const markAsDone = async () => {
  if (ticketStatus.value === 'resolved') return;
  
  isUpdating.value = true;
  try {
    await store.dispatch('tickets/updateTicket', {
      id: props.ticket.id,
      status: 'resolved'
    });
    emit('refresh');
  } catch (error) {
    console.error('Failed to mark ticket as done:', error);
  } finally {
    isUpdating.value = false;
  }
};

const escalateToJira = async () => {
  // This would integrate with JIRA API to create an issue
  console.log('Escalating ticket to JIRA:', props.ticket);
  // Implementation would depend on JIRA integration setup
};

const viewTicketDetails = () => {
  // Open ticket details modal or navigate to ticket view
  console.log('Opening ticket details for:', props.ticket);
};
</script>

<template>
  <div class="p-4 rounded-xl hover:bg-n-alpha-1 transition-all duration-200 shadow-sm hover:shadow-md border border-n-weak">
    <div class="flex items-start justify-between gap-4">
      <div class="flex-1 min-w-0">
        <!-- Ticket header -->
        <div class="flex items-center gap-3 mb-3">
          <button
            class="inline-flex items-center gap-2 text-purple-700 hover:text-purple-800 font-semibold text-sm bg-purple-50 hover:bg-purple-100 px-3 py-1.5 rounded-lg transition-colors"
            @click="viewTicketDetails"
          >
            <div class="w-4 h-4 bg-purple-600 rounded text-white text-xs flex items-center justify-center font-bold">
              T
            </div>
            #{{ ticket.id }}
          </button>
          
          <span v-if="createdAt" class="text-xs text-n-slate-10 hidden sm:block">
            {{ $t('TICKETS.CREATED') }}: {{ createdAt }}
          </span>
        </div>

        <!-- Ticket title -->
        <h4 class="text-sm font-medium text-n-slate-12 mb-3 line-clamp-2 leading-relaxed">
          {{ ticketTitle }}
        </h4>

        <!-- Ticket description -->
        <p v-if="ticketDescription" class="text-xs text-n-slate-10 mb-3 line-clamp-2">
          {{ ticketDescription }}
        </p>

        <!-- Ticket metadata -->
        <div class="flex flex-wrap items-center gap-2 mb-4">
          <span
            class="px-3 py-1.5 rounded-full text-xs font-medium border shadow-sm"
            :class="getStatusColor(ticketStatus)"
          >
            {{ $t(`TICKETS.STATUS.${ticketStatus.toUpperCase()}`) }}
          </span>
          <span
            class="px-3 py-1.5 rounded-full text-xs font-medium border shadow-sm"
            :class="getPriorityColor(ticketPriority)"
          >
            {{ $t(`TICKETS.PRIORITY.${ticketPriority.toUpperCase()}`) }}
          </span>
        </div>

        <!-- Action buttons -->
        <div class="flex items-center gap-2 flex-wrap">
          <NextButton
            v-if="ticketStatus !== 'resolved'"
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            :is-loading="isUpdating"
            class="hover:bg-green-50 hover:text-green-700"
            @click="markAsDone"
          >
            <i class="ri-check-line" />
            {{ $t('TICKETS.MARK_AS_DONE') }}
          </NextButton>
          
          <NextButton
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-blue-50 hover:text-blue-700"
            @click="escalateToJira"
          >
            <i class="ri-external-link-line" />
            {{ $t('TICKETS.ESCALATE_TO_JIRA') }}
          </NextButton>
          
          <NextButton
            size="tiny"
            variant="ghost"
            color-scheme="secondary"
            class="hover:bg-purple-50 hover:text-purple-700"
            @click="viewTicketDetails"
          >
            <i class="ri-eye-line" />
            {{ $t('TICKETS.VIEW_DETAILS') }}
          </NextButton>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
