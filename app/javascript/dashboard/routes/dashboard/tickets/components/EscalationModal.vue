<template>
  <BaseModal
    :show="show"
    @close="handleClose"
    :close-on-backdrop-click="false"
    size="medium"
  >
    <div class="p-6">
      <!-- Header -->
      <div class="flex items-center gap-3 mb-6">
        <div class="w-10 h-10 bg-orange-100 rounded-full flex items-center justify-center">
          <Icon icon="i-lucide-alert-triangle" class="w-5 h-5 text-orange-600" />
        </div>
        <div>
          <h3 class="text-lg font-semibold text-n-slate-12">
            {{ $t('TICKETS.KANBAN.ESCALATION_CONFIRM') }}
          </h3>
          <p class="text-sm text-n-slate-10">
            {{ $t('TICKETS.KANBAN.ESCALATION_CONFIRM_TEXT') }}
          </p>
        </div>
      </div>

      <!-- Ticket Info -->
      <div class="bg-n-alpha-1 rounded-lg p-4 mb-6">
        <h4 class="font-medium text-n-slate-12 mb-2">{{ ticket?.title || 'Untitled Ticket' }}</h4>
        <p class="text-sm text-n-slate-10 line-clamp-2">
          {{ ticket?.description || 'No description provided' }}
        </p>
        <div class="flex items-center gap-4 mt-3 text-xs text-n-slate-9">
          <span>Ticket #{{ ticket?.id }}</span>
          <span v-if="ticket?.priority" class="capitalize">{{ ticket.priority }} Priority</span>
        </div>
      </div>

      <!-- Escalation Note -->
      <div class="mb-6">
        <label class="block text-sm font-medium text-n-slate-11 mb-2">
          {{ $t('TICKETS.KANBAN.ESCALATION_NOTE') }}
        </label>
        <textarea
          v-model="escalationNote"
          :placeholder="$t('TICKETS.KANBAN.ESCALATION_NOTE_PLACEHOLDER')"
          class="w-full px-3 py-2 border border-n-weak rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
          rows="3"
          maxlength="500"
        />
        <div class="text-xs text-n-slate-9 mt-1">
          {{ escalationNote.length }}/500 characters
        </div>
      </div>

      <!-- Actions -->
      <div class="flex justify-end gap-3">
        <BaseButton
          variant="outline"
          size="medium"
          @click="handleClose"
          :disabled="isLoading"
        >
          {{ $t('TICKETS.KANBAN.CANCEL') }}
        </BaseButton>
        <BaseButton
          variant="solid"
          color="orange"
          size="medium"
          @click="handleEscalate"
          :loading="isLoading"
          :disabled="isLoading"
        >
          <Icon 
            v-if="isLoading" 
            icon="i-lucide-loader-2" 
            class="w-4 h-4 animate-spin mr-2" 
          />
          {{ isLoading ? $t('TICKETS.KANBAN.ESCALATING') : $t('TICKETS.KANBAN.CONFIRM_ESCALATE') }}
        </BaseButton>
      </div>
    </div>
  </BaseModal>
</template>

<script>
import { ref, computed, watch } from 'vue';
import BaseModal from 'dashboard/components/Modal.vue';
import BaseButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

export default {
  name: 'EscalationModal',
  components: {
    BaseModal,
    BaseButton,
    Icon,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    ticket: {
      type: Object,
      default: null,
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['close', 'escalate'],
  setup(props, { emit }) {
    const escalationNote = ref('');

    // Reset note when modal opens/closes
    watch(() => props.show, (newValue) => {
      if (newValue) {
        escalationNote.value = '';
      }
    });

    const handleClose = () => {
      if (!props.isLoading) {
        escalationNote.value = '';
        emit('close');
      }
    };

    const handleEscalate = () => {
      emit('escalate', {
        ticket: props.ticket,
        note: escalationNote.value.trim(),
      });
    };

    return {
      escalationNote,
      handleClose,
      handleEscalate,
    };
  },
};
</script>

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
