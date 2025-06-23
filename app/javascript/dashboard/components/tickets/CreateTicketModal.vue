<template>
  <Modal
    :show="true"
    :on-close="onClose"
    :close-on-backdrop-click="false"
    size="large"
  >
    <div class="h-auto overflow-auto max-h-[75vh] p-6">
      <ModalHeader
        :header-title="$t('TICKETS.CREATE_TICKET')"
        :header-content="$t('TICKETS.CREATE_TICKET_DESCRIPTION')"
      />
      
      <form @submit.prevent="createTicket" class="space-y-6">
        <!-- Title -->
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            {{ $t('TICKETS.TITLE') }} *
          </label>
          <input
            v-model="ticketForm.title"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
            :placeholder="$t('TICKETS.TITLE_PLACEHOLDER')"
            required
          />
          <p v-if="errors.title" class="mt-1 text-sm text-red-600">{{ errors.title[0] }}</p>
        </div>

        <!-- Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            {{ $t('TICKETS.DESCRIPTION') }}
          </label>
          <textarea
            v-model="ticketForm.description"
            rows="4"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
            :placeholder="$t('TICKETS.DESCRIPTION_PLACEHOLDER')"
          ></textarea>
          <p v-if="errors.description" class="mt-1 text-sm text-red-600">{{ errors.description[0] }}</p>
        </div>

        <!-- Priority -->
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            {{ $t('TICKETS.PRIORITY') }}
          </label>
          <select
            v-model="ticketForm.priority"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
          >
            <option value="low">{{ $t('TICKETS.PRIORITY_LOW') }}</option>
            <option value="medium">{{ $t('TICKETS.PRIORITY_MEDIUM') }}</option>
            <option value="high">{{ $t('TICKETS.PRIORITY_HIGH') }}</option>
            <option value="urgent">{{ $t('TICKETS.PRIORITY_URGENT') }}</option>
          </select>
        </div>

        <!-- Issue Type -->
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            {{ $t('TICKETS.ISSUE_TYPE') }}
          </label>
          <input
            v-model="ticketForm.issue_type"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
            :placeholder="$t('TICKETS.ISSUE_TYPE_PLACEHOLDER')"
          />
        </div>

        <!-- Assigned Agent -->
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            {{ $t('TICKETS.ASSIGNED_AGENT') }}
          </label>
          <select
            v-model="ticketForm.assigned_agent_id"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
          >
            <option value="">{{ $t('TICKETS.UNASSIGNED') }}</option>
            <option
              v-for="agent in availableAgents"
              :key="agent.id"
              :value="agent.id"
            >
              {{ agent.name }}
            </option>
          </select>
        </div>

        <!-- Selected Messages Preview -->
        <div v-if="selectedMessageIds.length > 0">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            {{ $t('TICKETS.SELECTED_MESSAGES_PREVIEW', { count: selectedMessageIds.length }) }}
          </label>
          <div class="max-h-40 overflow-y-auto border border-gray-200 dark:border-gray-600 rounded-md">
            <div
              v-for="message in selectedMessagesPreview"
              :key="message.id"
              class="p-3 border-b border-gray-100 dark:border-gray-700 last:border-b-0"
            >
              <div class="text-xs text-gray-500 mb-1">
                {{ formatMessageSender(message) }} • {{ formatDate(message.created_at) }}
              </div>
              <div class="text-sm text-gray-800 dark:text-gray-200 line-clamp-2">
                {{ message.content || $t('TICKETS.NO_CONTENT') }}
              </div>
            </div>
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
            :disabled="!ticketForm.title.trim()"
          >
            {{ $t('TICKETS.CREATE_TICKET') }}
          </ButtonV4>
        </div>
      </form>
    </div>
  </Modal>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import Modal from 'dashboard/components/Modal.vue';
import ModalHeader from 'dashboard/components/ModalHeader.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import TicketAPI from 'dashboard/api/tickets';
import { formatDate } from 'shared/helpers/DateHelper';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  selectedMessageIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'created']);

const { t } = useI18n();
const store = useStore();

const isLoading = ref(false);
const errors = ref({});

const ticketForm = ref({
  title: '',
  description: '',
  priority: 'medium',
  issue_type: '',
  assigned_agent_id: '',
  conversation_id: props.conversationId,
});

const currentUser = useMapGetter('getCurrentUser');
const availableAgents = computed(() => {
  return store.getters['inboxAssignableAgents/getAgents'] || [];
});

const selectedMessagesPreview = computed(() => {
  const conversationMessages = store.getters['conversationMessages/getMessages'] || [];
  return conversationMessages.filter(message => 
    props.selectedMessageIds.includes(message.id)
  ).slice(0, 5); // Show max 5 messages in preview
});

const formatMessageSender = (message) => {
  if (message.sender?.name) {
    return message.sender.name;
  }
  return message.message_type === 'incoming' ? t('TICKETS.CUSTOMER') : t('TICKETS.AGENT');
};

const createTicket = async () => {
  if (isLoading.value) return;
  
  isLoading.value = true;
  errors.value = {};

  try {
    const ticketData = {
      ...ticketForm.value,
      message_ids: props.selectedMessageIds,
    };

    const response = await TicketAPI.create(ticketData);
    
    emit('created', response.data);
    
    // Show success message
    store.dispatch('notifications/add', {
      message: t('TICKETS.CREATE_SUCCESS'),
      type: 'success',
    });
    
  } catch (error) {
    console.error('Error creating ticket:', error);
    
    if (error.response?.data?.errors) {
      errors.value = error.response.data.errors;
    } else {
      store.dispatch('notifications/add', {
        message: error.response?.data?.error || t('TICKETS.CREATE_ERROR'),
        type: 'error',
      });
    }
  } finally {
    isLoading.value = false;
  }
};

const onClose = () => {
  emit('close');
};

onMounted(() => {
  // Load available agents for the conversation's inbox
  const conversation = store.getters.getSelectedChat;
  if (conversation?.inbox_id) {
    store.dispatch('inboxAssignableAgents/fetch', [conversation.inbox_id]);
  }
});
</script>
