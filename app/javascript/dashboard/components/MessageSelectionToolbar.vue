<template>
  <div 
    v-if="isVisible" 
    class="fixed bottom-6 left-1/2 transform -translate-x-1/2 z-50"
  >
    <div class="bg-white dark:bg-slate-900 rounded-xl shadow-xl backdrop-blur-sm p-4 min-w-96 border-0">
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <div class="w-5 h-5 rounded bg-blue-100 dark:bg-blue-900 flex items-center justify-center">
            <i class="i-lucide-check text-blue-600 dark:text-blue-400 w-3 h-3" />
          </div>
          <span class="font-medium text-slate-900 dark:text-slate-100">
            {{ $t('TICKETS.SELECTED_MESSAGES', { count: selectedMessages.length }) }}
          </span>
        </div>
        <button
          @click="clearSelection"
          class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 p-1 rounded-md hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <i class="i-lucide-x w-4 h-4" />
        </button>
      </div>
      
      <div class="flex items-center gap-3">
        <ButtonV4
          size="sm"
          variant="primary"
          icon="i-lucide-ticket"
          @click="openCreateTicketModal"
        >
          {{ $t('TICKETS.CREATE_TICKET') }}
        </ButtonV4>
        
        <!-- <ButtonV4
          v-if="existingTickets.length > 0"
          size="sm"
          variant="secondary" 
          icon="i-lucide-link"
          @click="openLinkToExistingModal"
        >
          {{ $t('TICKETS.LINK_TO_EXISTING') }}
        </ButtonV4>
         -->
        <ButtonV4
          size="sm"
          variant="ghost"
          @click="clearSelection"
        >
          {{ $t('TICKETS.CANCEL') }}
        </ButtonV4>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';

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

const emit = defineEmits(['clear-selection', 'create-ticket', 'link-to-existing']);

const { t } = useI18n();
const store = useStore();

const isVisible = computed(() => props.selectedMessages.length > 0);

const existingTickets = computed(() => {
  return store.getters['tickets/getTicketsForConversation'](props.conversationId) || [];
});

const clearSelection = () => {
  emit('clear-selection');
};

const openCreateTicketModal = () => {
  emit('create-ticket');
};

const openLinkToExistingModal = () => {
  emit('link-to-existing');
};

// Load existing tickets when conversation changes
watch(() => props.conversationId, (newConversationId) => {
  if (newConversationId) {
    store.dispatch('tickets/fetchTicketsForConversation', newConversationId);
  }
}, { immediate: true });
</script>
