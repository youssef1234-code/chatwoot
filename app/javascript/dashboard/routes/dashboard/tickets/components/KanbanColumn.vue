<template>
  <div class="flex flex-col flex-1 bg-white dark:bg-n-slate-1 rounded-xl border border-n-weak shadow-sm min-w-80 mt-4 mr-4 mb-4">
    <!-- Column Header -->
    <div class="p-4 border-b border-n-weak">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div
            class="w-3 h-3 rounded-full"
            :class="getStatusColor(color)"
          />
          <h3 class="font-semibold text-n-slate-12">
            {{ title }}
          </h3>
          <span class="bg-n-alpha-2 text-n-slate-10 text-xs px-2 py-1 rounded-full">
            {{ tickets.length }}
          </span>
        </div>
      </div>
    </div>

    <!-- Column Content -->
    <div
      class="flex-1 p-4 space-y-3 overflow-y-auto transition-all duration-300 min-h-32 relative border-2 border-transparent"
      @drop="handleDrop"
      @dragover="handleDragOver"
      @dragenter="handleDragEnter"
      @dragleave="handleDragLeave"
      :class="{
        'bg-green-50 border-green-300 border-dashed transform scale-[1.02] shadow-xl': isDragOver && isValidDrop,
        'bg-red-50 border-red-300 border-dashed shadow-inner': isDragOver && !isValidDrop,
        'bg-n-alpha-1': !isDragOver
      }"
    >
      <!-- Drag Overlay -->
      <div
        v-if="isDragOver"
        class="absolute inset-0 flex items-center justify-center z-10 pointer-events-none backdrop-blur-sm drag-overlay"
      >
        <div
          class="px-8 py-6 rounded-xl shadow-2xl text-center transition-all duration-200 transform scale-110 border-2"
          :class="{
            'bg-green-100 text-green-800 border-green-300': isValidDrop,
            'bg-red-100 text-red-800 border-red-300': !isValidDrop
          }"
        >
          <Icon
            :icon="isValidDrop ? 'i-lucide-check-circle' : 'i-lucide-x-circle'"
            :class="{
              'text-green-600': isValidDrop,
              'text-red-600': !isValidDrop
            }"
            class="w-12 h-12 mx-auto mb-3"
          />
          <p class="font-bold text-xl mb-2">
            {{ isValidDrop ? getDragHintText() : $t('TICKETS.KANBAN.DRAG_HINT_INVALID') }}
          </p>
          <p class="text-sm opacity-75">
            {{ isValidDrop ? 'Release to apply' : 'This transition is not allowed' }}
          </p>
        </div>
      </div>
      <!-- Loading State -->
      <div v-if="isLoading" class="space-y-3">
        <div
          v-for="n in 3"
          :key="n"
          class="animate-pulse bg-n-alpha-2 rounded-lg h-32"
        />
      </div>

      <!-- Empty State -->
      <div
        v-else-if="tickets.length === 0"
        class="flex flex-col items-center justify-center py-8 text-center"
      >
        <Icon icon="i-lucide-clipboard-list" class="w-12 h-12 text-n-slate-7 mb-2" />
        <p class="text-sm text-n-slate-9">
          {{ $t('TICKETS.KANBAN.NO_TICKETS') }}
        </p>
      </div>

      <!-- Tickets -->
      <TicketCard
        v-for="ticket in tickets"
        :key="ticket.id"
        :ticket="ticket"
        :color="color"
        :draggable="true"
        :class="{
          'opacity-50 transform rotate-2 scale-95': draggedTicket && draggedTicket.id === ticket.id
        }"
        class="transition-all duration-200"
        @click="$emit('ticket-click', ticket)"
        @dragstart="handleDragStart(ticket, $event)"
        @dragend="handleDragEnd"
        @enhance-with-ai="$emit('enhance-with-ai', ticket)"
      />
    </div>
  </div>
</template>

<script>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketCard from './TicketCard.vue';

export default {
  name: 'KanbanColumn',
  components: {
    Icon,
    TicketCard,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    tickets: {
      type: Array,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
    status: {
      type: String,
      required: true,
    },
    color: {
      type: String,
      default: 'blue',
    },
    canAcceptDrop: {
      type: Function,
      default: () => true,
    },
  },
  emits: ['ticket-move', 'ticket-click', 'enhance-with-ai'],
  setup(props, { emit }) {
    const { t } = useI18n();
    
    // State
    const isDragOver = ref(false);
    const isValidDrop = ref(true);
    const draggedTicket = ref(null);

    // Methods
    const getStatusColor = (color) => {
      const colorMap = {
        blue: 'bg-blue-500',
        yellow: 'bg-yellow-500',
        orange: 'bg-orange-500',
        green: 'bg-green-500',
        red: 'bg-red-500',
      };
      return colorMap[color] || 'bg-gray-500';
    };

    const handleDragStart = (ticket, event) => {
      draggedTicket.value = ticket;
      // The TicketCard already sets the drag data, so we don't need to do it again
    };

    const handleDragEnd = (event) => {
      draggedTicket.value = null;
      isDragOver.value = false;
      isValidDrop.value = true;
    };

    const canAcceptTicket = (ticket) => {
      // Use the parent's validation function if provided
      if (props.canAcceptDrop) {
        return props.canAcceptDrop(ticket, props.status);
      }
      return true;
    };

    const handleDragOver = (event) => {
      event.preventDefault();
      
      // Check if this is a valid drop target
      if (draggedTicket.value && canAcceptTicket(draggedTicket.value)) {
        event.dataTransfer.dropEffect = 'move';
        isValidDrop.value = true;
      } else {
        event.dataTransfer.dropEffect = 'none';
        isValidDrop.value = false;
      }
    };

    const handleDragEnter = (event) => {
      event.preventDefault();
      isDragOver.value = true;
      
      // Set validity based on the ticket being dragged
      if (draggedTicket.value) {
        isValidDrop.value = canAcceptTicket(draggedTicket.value);
      }
    };

    const handleDragLeave = (event) => {
      // Only hide drag over if leaving the column entirely
      const rect = event.currentTarget.getBoundingClientRect();
      const x = event.clientX;
      const y = event.clientY;
      
      if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) {
        isDragOver.value = false;
        isValidDrop.value = true;
      }
    };

    const handleDrop = async (event) => {
      event.preventDefault();
      isDragOver.value = false;
      isValidDrop.value = true;
      
      try {
        const ticketData = JSON.parse(event.dataTransfer.getData('ticket'));
        if (ticketData && ticketData.id && canAcceptTicket(ticketData)) {
          const success = await emit('ticket-move', ticketData, props.status);
          
          // If the move failed, we could add additional feedback here
          if (success === false) {
            // Handle failed move
            console.log('Ticket move was rejected');
          }
        }
      } catch (error) {
        console.error('Failed to parse dropped ticket data:', error);
      }
    };

    const getDragHintText = () => {
      if (!isValidDrop.value) {
        return t('TICKETS.KANBAN.DRAG_HINT_INVALID');
      }
      
      const actionKey = props.status === 'done' ? 'ACTION_RESOLVE' : 'ACTION_ESCALATE';
      return t('TICKETS.KANBAN.DRAG_HINT_VALID', { 
        action: t(`TICKETS.KANBAN.${actionKey}`)
      });
    };

    return {
      // State
      isDragOver,
      isValidDrop,
      draggedTicket,
      
      // Methods
      getStatusColor,
      handleDragStart,
      handleDragEnd,
      handleDragOver,
      handleDragEnter,
      handleDragLeave,
      handleDrop,
      canAcceptTicket,
      getDragHintText,
    };
  },
};
</script>

<style scoped>
/* Drag and drop styles */
.drag-over {
  border: 2px dashed #3b82f6;
  background-color: #eff6ff;
}

/* Scrollbar styles */
.overflow-y-auto::-webkit-scrollbar {
  width: 4px;
}

.overflow-y-auto::-webkit-scrollbar-track {
  background: transparent;
}

.overflow-y-auto::-webkit-scrollbar-thumb {
  background: rgba(156, 163, 175, 0.5);
  border-radius: 2px;
}

.overflow-y-auto::-webkit-scrollbar-thumb:hover {
  background: rgba(156, 163, 175, 0.7);
}

/* Animation keyframes */
@keyframes bounceIn {
  0% {
    transform: scale(0.8);
    opacity: 0;
  }
  50% {
    transform: scale(1.1);
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}

@keyframes pulse {
  0%, 100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.05);
  }
}

/* Apply animations */
.drag-overlay {
  animation: bounceIn 0.3s ease-out;
}

.pulse-animation {
  animation: pulse 2s infinite;
}
</style>
