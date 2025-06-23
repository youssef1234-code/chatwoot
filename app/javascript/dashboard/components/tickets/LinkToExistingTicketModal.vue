<template>
  <Modal
    :show="true"
    :on-close="onClose"
    :close-on-backdrop-click="false"
    size="medium"
  >
    <div class="h-auto overflow-auto max-h-[75vh] p-6">
      <ModalHeader
        :header-title="$t('TICKETS.LINK_TO_EXISTING')"
        :header-content="$t('TICKETS.LINK_TO_EXISTING_DESCRIPTION')"
      />
      
      <form @submit.prevent="linkMessages" class="space-y-6">
        <!-- Ticket Selection -->
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            {{ $t('TICKETS.SELECT_TICKET') }} *
          </label>
          <select
            v-model="selectedTicketId"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
            required
          >
            <option value="">{{ $t('TICKETS.SELECT_TICKET_PLACEHOLDER') }}</option>
            <option
              v-for="ticket in availableTickets"
              :key="ticket.id"
              :value="ticket.id"
            >
              #{{ ticket.id }} - {{ ticket.title }} ({{ $t(`TICKETS.STATUS_${ticket.status.toUpperCase()}`) }})
            </option>
          </select>
        </div>

        <!-- Selected Ticket Preview -->
        <div v-if="selectedTicket" class="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
          <h4 class="font-medium text-gray-900 dark:text-white mb-2">
            {{ $t('TICKETS.SELECTED_TICKET_PREVIEW') }}
          </h4>
          <div class="space-y-2 text-sm">
            <div>
              <span class="font-medium">{{ $t('TICKETS.TITLE') }}:</span>
              {{ selectedTicket.title }}
            </div>
            <div>
              <span class="font-medium">{{ $t('TICKETS.STATUS') }}:</span>
              <span 
                class="inline-block px-2 py-1 rounded-full text-xs"
                :class="getStatusClass(selectedTicket.status)"
              >
                {{ $t(`TICKETS.STATUS_${selectedTicket.status.toUpperCase()}`) }}
              </span>
            </div>
            <div>
              <span class="font-medium">{{ $t('TICKETS.PRIORITY') }}:</span>
              <span 
                class="inline-block px-2 py-1 rounded-full text-xs"
                :class="getPriorityClass(selectedTicket.priority)"
              >
                {{ $t(`TICKETS.PRIORITY_${selectedTicket.priority.toUpperCase()}`) }}
              </span>
            </div>
            <div v-if="selectedTicket.description">
              <span class="font-medium">{{ $t('TICKETS.DESCRIPTION') }}:</span>
              <p class="text-gray-600 dark:text-gray-400 mt-1">{{ selectedTicket.description }}</p>
            </div>
          </div>
        </div>

        <!-- Selected Messages Count -->
        <div class="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-4">
          <div class="flex items-center gap-2">
            <i class="i-lucide-info w-4 h-4 text-blue-600" />
            <span class="text-sm text-blue-800 dark:text-blue-200">
              {{ $t('TICKETS.LINK_MESSAGES_INFO', { count: selectedMessageIds.length }) }}
            </span>
          </div>
        </div>

        <!-- Actions -->
        <div class="flex justify-end gap-3 pt-4">
          <ButtonV4
            type="button"
            variant="secondary"
            @click="onClose"
            :disabled="isLoading"
          >
            {{ $t('TICKETS.CANCEL') }}
          </ButtonV4>
          
          <ButtonV4
            type="submit"
            variant="primary"
            :loading="isLoading"
            :disabled="!selectedTicketId"
          >
            {{ $t('TICKETS.LINK_MESSAGES') }}
          </ButtonV4>
        </div>
      </form>
    </div>
  </Modal>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import Modal from 'dashboard/components/Modal.vue';
import ModalHeader from 'dashboard/components/ModalHeader.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import TicketAPI from 'dashboard/api/tickets';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  selectedMessageIds: {
    type: Array,
    default: () => [],
  },
  existingTickets: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'linked']);

const { t } = useI18n();
const store = useStore();

const isLoading = ref(false);
const selectedTicketId = ref('');

const availableTickets = computed(() => {
  // Only show open, in_progress, or escalated tickets
  return props.existingTickets.filter(ticket => 
    ['open', 'in_progress', 'escalated'].includes(ticket.status)
  );
});

const selectedTicket = computed(() => {
  return availableTickets.value.find(ticket => ticket.id === selectedTicketId.value);
});

const getStatusClass = (status) => {
  const classes = {
    open: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
    in_progress: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
    escalated: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200',
    resolved: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
    closed: 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200',
  };
  return classes[status] || classes.open;
};

const getPriorityClass = (priority) => {
  const classes = {
    low: 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200',
    medium: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
    high: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200',
    urgent: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
  };
  return classes[priority] || classes.medium;
};

const linkMessages = async () => {
  if (isLoading.value || !selectedTicketId.value) return;
  
  isLoading.value = true;

  try {
    await TicketAPI.addMessages(selectedTicketId.value, {
      message_ids: props.selectedMessageIds,
    });
    
    const ticket = selectedTicket.value;
    emit('linked', ticket);
    
    // Show success message
    store.dispatch('notifications/add', {
      message: t('TICKETS.LINK_SUCCESS', { title: ticket.title }),
      type: 'success',
    });
    
  } catch (error) {
    console.error('Error linking messages to ticket:', error);
    
    store.dispatch('notifications/add', {
      message: error.response?.data?.error || t('TICKETS.LINK_ERROR'),
      type: 'error',
    });
  } finally {
    isLoading.value = false;
  }
};

const onClose = () => {
  emit('close');
};
</script>
