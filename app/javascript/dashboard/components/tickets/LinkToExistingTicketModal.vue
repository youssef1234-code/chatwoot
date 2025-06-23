<template>
  <Modal
    :show="true"
    :on-close="onClose"
    :close-on-backdrop-click="false"
  >
    <div class="w-full max-w-2xl mx-auto">
      <div class="flex flex-col h-[600px]">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600">
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {{ $t('TICKETS.LINK_TO_EXISTING') }}
          </h2>
        </div>
        
        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-6">
          <div class="mb-6">
            <p class="text-sm text-n-slate-11 mb-4">
              {{ $t('TICKETS.LINK_TO_EXISTING_DESCRIPTION') }}
            </p>
            
            <!-- Selected Messages Preview -->
            <div v-if="selectedMessageIds.length > 0" class="mb-6">
              <h3 class="text-sm font-medium text-n-slate-12 mb-3">
                {{ $t('TICKETS.SELECTED_MESSAGES_PREVIEW', { count: selectedMessageIds.length }) }}
              </h3>
              <div class="bg-n-slate-2 rounded-lg p-4 max-h-32 overflow-y-auto">
                <div v-for="message in selectedMessagesPreview" :key="message.id" class="mb-3 last:mb-0">
                  <div class="flex items-start gap-3">
                    <div class="text-xs text-n-slate-10">
                      {{ formatMessageSender(message) }}:
                    </div>
                    <div class="text-sm text-n-slate-12 flex-1 line-clamp-2">
                      {{ message.content || $t('TICKETS.NO_CONTENT') }}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Ticket Selection -->
          <div class="mb-6">
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ $t('TICKETS.SELECT_TICKET') }} *
            </label>
            
            <!-- Search for tickets -->
            <div class="mb-4">
              <input
                v-model="searchQuery"
                type="text"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                :placeholder="$t('TICKETS.SEARCH_TICKETS')"
                @input="searchTickets"
              />
            </div>
            
            <!-- Tickets list -->
            <div v-if="isLoadingTickets" class="flex justify-center p-4">
              <div class="text-sm text-n-slate-10">{{ $t('TICKETS.LOADING_TICKETS') }}</div>
            </div>
            
            <div v-else-if="availableTickets.length > 0" class="border border-n-slate-6 rounded-md max-h-64 overflow-y-auto">
              <div
                v-for="ticket in availableTickets"
                :key="ticket.id"
                class="p-3 hover:bg-n-slate-2 cursor-pointer border-b border-n-slate-4 last:border-b-0"
                :class="{ 'bg-blue-50 border-blue-200': selectedTicket?.id === ticket.id }"
                @click="selectTicket(ticket)"
              >
                <div class="flex items-start justify-between gap-3">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 mb-1">
                      <span class="text-sm font-medium text-purple-700">#{{ ticket.id }}</span>
                      <span
                        class="px-2 py-0.5 rounded text-xs font-medium"
                        :class="getStatusColor(ticket.status)"
                      >
                        {{ $t(`TICKETS.STATUS.${ticket.status.toUpperCase()}`) }}
                      </span>
                    </div>
                    <h4 class="text-sm font-medium text-n-slate-12 mb-1 line-clamp-1">
                      {{ ticket.title }}
                    </h4>
                    <p v-if="ticket.description" class="text-xs text-n-slate-10 line-clamp-2">
                      {{ ticket.description }}
                    </p>
                  </div>
                </div>
              </div>
            </div>
            
            <div v-else class="text-center py-8">
              <div class="text-sm text-n-slate-10">
                {{ searchQuery ? $t('TICKETS.NO_TICKETS_FOUND') : $t('TICKETS.NO_AVAILABLE_TICKETS') }}
              </div>
            </div>
          </div>

          <!-- Selected Ticket Preview -->
          <div v-if="selectedTicket" class="mb-6">
            <h3 class="text-sm font-medium text-n-slate-12 mb-3">
              {{ $t('TICKETS.SELECTED_TICKET_PREVIEW') }}
            </h3>
            <div class="bg-blue-50 rounded-lg p-4 border border-blue-200">
              <div class="flex items-center gap-2 mb-2">
                <span class="text-sm font-medium text-purple-700">#{{ selectedTicket.id }}</span>
                <span
                  class="px-2 py-0.5 rounded text-xs font-medium"
                  :class="getStatusColor(selectedTicket.status)"
                >
                  {{ $t(`TICKETS.STATUS.${selectedTicket.status.toUpperCase()}`) }}
                </span>
              </div>
              <h4 class="text-sm font-medium text-n-slate-12 mb-2">
                {{ selectedTicket.title }}
              </h4>
              <p v-if="selectedTicket.description" class="text-xs text-n-slate-10">
                {{ selectedTicket.description }}
              </p>
            </div>
            
            <div class="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
              <p class="text-sm text-yellow-800">
                {{ $t('TICKETS.LINK_MESSAGES_INFO', { count: selectedMessageIds.length }) }}
              </p>
            </div>
          </div>
        </div>
        
        <!-- Footer -->
        <div class="flex items-center justify-end gap-3 p-6 border-t border-slate-200 dark:border-slate-600">
          <Button
            variant="ghost"
            @click="onClose"
            :disabled="isLinking"
          >
            {{ $t('TICKETS.CANCEL') }}
          </Button>
          <Button
            color-scheme="success"
            :is-loading="isLinking"
            :disabled="!selectedTicket"
            @click="linkMessagesToTicket"
          >
            {{ $t('TICKETS.LINK_MESSAGES') }}
          </Button>
        </div>
      </div>
    </div>
  </Modal>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TicketsAPI from 'dashboard/api/tickets';

const props = defineProps({
  conversationId: {
    type: [String, Number],
    required: true,
  },
  selectedMessageIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'linked']);

const { t } = useI18n();
const store = useStore();

const isLinking = ref(false);
const isLoadingTickets = ref(false);
const searchQuery = ref('');
const availableTickets = ref([]);
const selectedTicket = ref(null);

const currentChat = computed(() => store.getters.getSelectedChat);

const selectedMessagesPreview = computed(() => {
  const conversation = currentChat.value;
  if (!conversation || !conversation.messages) {
    return [];
  }
  
  return conversation.messages
    .filter(message => props.selectedMessageIds.includes(message.id));
});

const getStatusColor = (status) => {
  const colors = {
    open: 'bg-blue-50 text-blue-700 border-blue-200',
    in_progress: 'bg-yellow-50 text-yellow-700 border-yellow-200',
    escalated: 'bg-orange-50 text-orange-700 border-orange-200',
    resolved: 'bg-green-50 text-green-700 border-green-200',
    closed: 'bg-gray-50 text-gray-700 border-gray-200',
  };
  return colors[status] || colors.open;
};

const formatMessageSender = (message) => {
  if (message.message_type === 0) {
    return message.sender?.name || t('TICKETS.CUSTOMER');
  }
  return message.sender?.name || t('TICKETS.AGENT');
};

const loadTickets = async () => {
  isLoadingTickets.value = true;
  try {
    const response = await TicketsAPI.getAll({
      conversation_id: props.conversationId,
      status: ['open', 'in_progress', 'escalated'], // Only show tickets that can accept new messages
    });
    availableTickets.value = response.data || [];
  } catch (error) {
    console.error('Failed to load tickets:', error);
    availableTickets.value = [];
  } finally {
    isLoadingTickets.value = false;
  }
};

const searchTickets = async () => {
  if (!searchQuery.value.trim()) {
    await loadTickets();
    return;
  }

  isLoadingTickets.value = true;
  try {
    const response = await TicketsAPI.getAll({
      q: searchQuery.value,
      status: ['open', 'in_progress', 'escalated'],
    });
    availableTickets.value = response.data || [];
  } catch (error) {
    console.error('Failed to search tickets:', error);
    availableTickets.value = [];
  } finally {
    isLoadingTickets.value = false;
  }
};

const selectTicket = (ticket) => {
  selectedTicket.value = ticket;
};

const linkMessagesToTicket = async () => {
  if (!selectedTicket.value || props.selectedMessageIds.length === 0) {
    return;
  }
  
  isLinking.value = true;
  
  try {
    await TicketsAPI.addMessages(selectedTicket.value.id, {
      message_ids: props.selectedMessageIds,
    });
    
    useAlert(t('TICKETS.LINK_SUCCESS', { title: selectedTicket.value.title }));
    emit('linked', selectedTicket.value);
    onClose();
  } catch (error) {
    console.error('Error linking messages to ticket:', error);
    useAlert(t('TICKETS.LINK_ERROR'));
  } finally {
    isLinking.value = false;
  }
};

const onClose = () => {
  emit('close');
};

onMounted(() => {
  loadTickets();
});
</script>

<style scoped>
.line-clamp-1 {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
