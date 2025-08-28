<template>
  <div
    v-if="show"
    class="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50"
    @click="handleBackdropClick"
  >
    <div
      class="bg-white dark:bg-n-slate-1 p-6 rounded-lg shadow-xl max-w-md w-full mx-4 transform transition-all duration-200"
      @click.stop
    >
      <div class="flex items-center gap-3 mb-4">
        <div class="w-10 h-10 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center">
          <Icon icon="i-lucide-alert-triangle" class="w-5 h-5 text-red-600 dark:text-red-400" />
        </div>
        <h3 class="text-lg font-semibold text-n-slate-12">
          {{ $t("TICKETS.ACTIONS.DELETE_CONFIRMATION") }}
        </h3>
      </div>
      
      <p class="text-n-slate-10 mb-6">
        {{ $t("TICKETS.ACTIONS.DELETE_CONFIRMATION_MESSAGE") }}
      </p>
      
      <div class="flex gap-3 justify-end">
        <NextButton
          variant="ghost"
          @click="handleCancel"
          :disabled="isDeleting"
        >
          {{ $t("TICKETS.CANCEL") }}
        </NextButton>
        <NextButton
          variant="danger"
          @click="handleConfirm"
          :loading="isDeleting"
          :disabled="isDeleting"
        >
          {{ $t("TICKETS.ACTIONS.DELETE_TICKET") }}
        </NextButton>
      </div>
    </div>
  </div>
</template>

<script>
import { defineComponent } from 'vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

export default defineComponent({
  name: 'DeleteTicketConfirmationModal',
  components: {
    NextButton,
    Icon,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    isDeleting: {
      type: Boolean,
      default: false,
    },
    ticket: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: ['confirm', 'cancel'],
  setup(props, { emit }) {
    const handleConfirm = () => {
      emit('confirm');
    };

    const handleCancel = () => {
      emit('cancel');
    };

    const handleBackdropClick = () => {
      if (!props.isDeleting) {
        emit('cancel');
      }
    };

    return {
      handleConfirm,
      handleCancel,
      handleBackdropClick,
    };
  },
});
</script>

<style scoped>
/* Enhanced backdrop blur effect */
.backdrop-blur-sm {
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
}

/* Animation for modal appearance */
@keyframes modalFadeIn {
  from {
    opacity: 0;
    transform: scale(0.95) translateY(-10px);
  }
  to {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
}

.transform {
  animation: modalFadeIn 0.2s ease-out;
}
</style>
