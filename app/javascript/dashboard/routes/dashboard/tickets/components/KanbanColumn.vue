<template>
  <div class="flex flex-col w-80 bg-white dark:bg-n-slate-1 rounded-xl border border-n-weak shadow-sm">
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
      class="flex-1 p-4 space-y-3 overflow-y-auto"
      @drop="handleDrop"
      @dragover="handleDragOver"
      @dragenter="handleDragEnter"
      @dragleave="handleDragLeave"
      :class="{ 'bg-n-alpha-1': isDragOver }"
    >
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
  },
  emits: ['ticket-move', 'ticket-click', 'enhance-with-ai'],
  setup(props, { emit }) {
    // State
    const isDragOver = ref(false);
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
      event.dataTransfer.setData('ticket', JSON.stringify(ticket));
      event.dataTransfer.effectAllowed = 'move';
    };

    const handleDragEnd = () => {
      draggedTicket.value = null;
      isDragOver.value = false;
    };

    const handleDragOver = (event) => {
      event.preventDefault();
      event.dataTransfer.dropEffect = 'move';
    };

    const handleDragEnter = (event) => {
      event.preventDefault();
      isDragOver.value = true;
    };

    const handleDragLeave = (event) => {
      // Only hide drag over if leaving the column entirely
      const rect = event.currentTarget.getBoundingClientRect();
      const x = event.clientX;
      const y = event.clientY;
      
      if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) {
        isDragOver.value = false;
      }
    };

    const handleDrop = (event) => {
      event.preventDefault();
      isDragOver.value = false;
      
      try {
        const ticketData = JSON.parse(event.dataTransfer.getData('ticket'));
        if (ticketData && ticketData.id) {
          emit('ticket-move', ticketData, props.status);
        }
      } catch (error) {
        console.error('Failed to parse dropped ticket data:', error);
      }
    };

    return {
      // State
      isDragOver,
      draggedTicket,
      
      // Methods
      getStatusColor,
      handleDragStart,
      handleDragEnd,
      handleDragOver,
      handleDragEnter,
      handleDragLeave,
      handleDrop,
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
</style>
