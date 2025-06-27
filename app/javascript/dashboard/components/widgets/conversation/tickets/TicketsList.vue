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
const isLoadingMore = ref(false);

// Initial load amounts per requirement
const INITIAL_LINKED_TICKETS = 10;
const PAGINATION_SIZE = 25;

const allTickets = computed(() => {
  const tickets = store.getters['tickets/getTicketsForConversation'](props.conversationId) || [];
  return tickets.sort((a, b) => b.id - a.id);
});

const ticketsMeta = computed(() => {
  return store.getters['tickets/getConversationTicketsMeta'](props.conversationId);
});

const hasTickets = computed(() => allTickets.value.length > 0);
const canLoadMore = computed(() => ticketsMeta.value.hasMore && !isLoading.value);

// Track what we've loaded to determine initial vs pagination loads
const hasLoadedInitial = ref(false);

const loadLinkedTickets = async (loadMore = false) => {
  if (loadMore) {
    isLoadingMore.value = true;
  } else {
    isLoading.value = true;
    hasLoadedInitial.value = false;
  }
  
  try {
    if (loadMore) {
      // Load more with standard pagination
      await store.dispatch('tickets/loadMoreTicketsForConversation', props.conversationId);
    } else {
      // Initial load: get first 10 tickets (mixed JIRA and non-JIRA)
      await store.dispatch('tickets/fetchTicketsForConversation', {
        conversationId: props.conversationId,
        page: 1,
        per_page: INITIAL_LINKED_TICKETS,
        append: false,
      });
      
      hasLoadedInitial.value = true;
    }
  } catch (error) {
    console.error('Failed to load linked tickets:', error);
  } finally {
    isLoading.value = false;
    isLoadingMore.value = false;
  }
};

const loadMoreTickets = () => {
  if (canLoadMore.value) {
    loadLinkedTickets(true);
  }
};

// Display logic: show limited amounts initially, then all when more are loaded
const displayedTickets = computed(() => {
  if (!hasLoadedInitial.value || isLoadingMore.value || canLoadMore.value) {
    // Show only first 10 tickets initially (mixed JIRA and non-JIRA)
    return allTickets.value.slice(0, INITIAL_LINKED_TICKETS);
  }
  return allTickets.value;
});

const hasMoreTickets = computed(() => {
  return allTickets.value.length > INITIAL_LINKED_TICKETS;
});

const shouldShowLoadMore = computed(() => {
  return hasLoadedInitial.value && (
    canLoadMore.value || 
    (hasMoreTickets.value && displayedTickets.value.length === INITIAL_LINKED_TICKETS)
  );
});

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
      <!-- All Tickets Section -->
      <div>
        <h4 class="text-sm font-medium text-n-slate-12 mb-2">
          {{ $t('TICKETS.LINKED_TICKETS') }} ({{ allTickets.length }})
          <span v-if="hasMoreTickets && displayedTickets.length === INITIAL_LINKED_TICKETS" class="text-n-slate-11">
            - showing first {{ INITIAL_LINKED_TICKETS }}
          </span>
        </h4>
        <div class="space-y-2">
          <TicketItem
            v-for="ticket in displayedTickets"
            :key="ticket.id"
            :ticket="ticket"
            :conversation-id="props.conversationId"
            @refresh="loadLinkedTickets"
          />
        </div>
      </div>

      <!-- Load More Button -->
      <div v-if="shouldShowLoadMore" class="flex justify-center pt-4">
        <NextButton
          :loading="isLoadingMore"
          variant="outline"
          size="small"
          @click="loadMoreTickets"
        >
          {{ $t('TICKETS.LOAD_MORE') }}
        </NextButton>
      </div>
    </div>
  </div>
</template>
