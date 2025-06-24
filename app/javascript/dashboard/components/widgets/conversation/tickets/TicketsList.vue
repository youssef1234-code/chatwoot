<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TicketItem from './TicketItem.vue';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const isLoading = ref(false);

const linkedTickets = computed(() => {
  const tickets = store.getters['tickets/getTicketsForConversation'](props.conversationId) || [];
  // Sort tickets by ID in descending order (newest first)
  return tickets.sort((a, b) => b.id - a.id);
});

const hasTickets = computed(() => linkedTickets.value.length > 0);

const loadLinkedTickets = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('tickets/fetchTicketsForConversation', props.conversationId);
  } catch (error) {
    console.error('Failed to load linked tickets:', error);
  } finally {
    isLoading.value = false;
  }
};

// Load tickets when component mounts
onMounted(() => {
  loadLinkedTickets();
});

// Watch for conversation changes
watch(() => props.conversationId, (newId) => {
  if (newId) {
    loadLinkedTickets();
  }
});

// Listen for ticket updates
const handleTicketUpdate = () => {
  loadLinkedTickets();
};

onMounted(() => {
  emitter.on('TICKET_UPDATED', handleTicketUpdate);
});

onUnmounted(() => {
  emitter.off('TICKET_UPDATED', handleTicketUpdate);
});
</script>

<template>
  <div>
    <div v-if="isLoading" class="flex justify-center p-8">
      <Spinner />
    </div>

    <div v-else-if="!hasTickets" class="flex justify-center p-4">
      <p class="text-sm text-n-slate-11">
        {{ $t('TICKETS.NO_LINKED_TICKETS') }}
      </p>
    </div>

    <div v-else class="space-y-2 px-4 pb-4">
      <TicketItem
        v-for="ticket in linkedTickets"
        :key="ticket.id"
        :ticket="ticket"
        :conversation-id="props.conversationId"
        @refresh="loadLinkedTickets"
      />
    </div>
  </div>
</template>
