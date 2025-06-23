<template>
  <div 
    v-if="isVisible" 
    class="fixed bottom-4 left-1/2 transform -translate-x-1/2 z-50"
  >
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg border border-gray-200 dark:border-gray-600 p-4 min-w-96">
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <i class="i-lucide-check-square text-blue-600" />
          <span class="font-semibold text-gray-900 dark:text-white">
            {{ $t('TICKETS.SELECTED_MESSAGES', { count: selectedMessages.length }) }}
          </span>
        </div>
        <button
          @click="clearSelection"
          class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
        >
          <i class="i-lucide-x w-4 h-4" />
        </button>
      </div>
      
      <div class="flex items-center gap-2">
        <ButtonV4
          size="sm"
          variant="primary"
          icon="i-lucide-ticket"
          @click="openCreateTicketModal"
        >
          {{ $t('TICKETS.CREATE_TICKET') }}
        </ButtonV4>
        
        <ButtonV4
          v-if="existingTickets.length > 0"
          size="sm"
          variant="secondary" 
          icon="i-lucide-link"
          @click="showLinkToExistingModal = true"
        >
          {{ $t('TICKETS.LINK_TO_EXISTING') }}
        </ButtonV4>
        
        <ButtonV4
          size="sm"
          variant="ghost"
          @click="clearSelection"
        >
          {{ $t('TICKETS.CANCEL') }}
        </ButtonV4>
      </div>
    </div>
    
    <!-- Create Ticket Modal -->
    <CreateTicketModal
      v-if="showCreateTicketModal"
      :conversation-id="conversationId"
      :selected-message-ids="selectedMessages"
      @close="showCreateTicketModal = false"
      @created="handleTicketCreated"
    />
    
    <!-- Link to Existing Ticket Modal -->
    <LinkToExistingTicketModal
      v-if="showLinkToExistingModal"
      :conversation-id="conversationId"
      :selected-message-ids="selectedMessages"
      :existing-tickets="existingTickets"
      @close="showLinkToExistingModal = false"
      @linked="handleMessagesLinked"
    />
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import CreateTicketModal from './tickets/CreateTicketModal.vue';
import LinkToExistingTicketModal from './tickets/LinkToExistingTicketModal.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  selectedMessages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['clear-selection', 'ticket-created', 'messages-linked']);

const { t } = useI18n();
const store = useStore();

const showCreateTicketModal = ref(false);
const showLinkToExistingModal = ref(false);

const isVisible = computed(() => props.selectedMessages.length > 0);

const existingTickets = computed(() => {
  return store.getters['tickets/getTicketsForConversation'](props.conversationId) || [];
});

const clearSelection = () => {
  emit('clear-selection');
};

const openCreateTicketModal = () => {
  showCreateTicketModal.value = true;
};

const handleTicketCreated = (ticket) => {
  showCreateTicketModal.value = false;
  clearSelection();
  emit('ticket-created', ticket);
};

const handleMessagesLinked = (ticket) => {
  showLinkToExistingModal.value = false;
  clearSelection();
  emit('messages-linked', ticket);
};

// Load existing tickets when conversation changes
watch(() => props.conversationId, (newConversationId) => {
  if (newConversationId) {
    store.dispatch('tickets/fetchTicketsForConversation', newConversationId);
  }
}, { immediate: true });
</script>
