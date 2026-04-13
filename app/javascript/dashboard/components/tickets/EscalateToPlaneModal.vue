<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CreateOrLinkIssue from 'dashboard/components/widgets/conversation/plane/CreateOrLinkIssue.vue';

const props = defineProps({
  ticket: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'escalated']);

const { t } = useI18n();
const store = useStore();

const isEscalating = ref(false);

const generatePlaneTitle = () => {
  return `[Ticket #${props.ticket.id}] ${props.ticket.title}`;
};

const generatePlaneDescription = () => {
  let description = `Escalated from Chatwoot Ticket #${props.ticket.id}\n\n`;
  
  if (props.ticket.description) {
    description += `**Original Description:**\n${props.ticket.description}\n\n`;
  }
  
  description += `**Ticket Details:**\n`;
  description += `- Priority: ${props.ticket.priority || 'Medium'}\n`;
  description += `- Status: ${props.ticket.status || 'Open'}\n`;
  
  if (props.ticket.category) {
    description += `- Category: ${props.ticket.category}\n`;
  }
  
  if (props.ticket.created_by) {
    description += `- Created by: ${props.ticket.created_by.name}\n`;
  }
  
  description += `- Created at: ${new Date(props.ticket.created_at).toLocaleString()}\n`;
  
  // Add conversation link if available
  if (props.ticket.conversation?.id) {
    const baseUrl = window.location.origin;
    const conversationUrl = `${baseUrl}/app/accounts/${store.getters.getCurrentAccountId}/conversations/${props.ticket.conversation.id}`;
    description += `\n**Related Conversation:** ${conversationUrl}`;
  }
  
  return description;
};

const onPlaneIssueCreated = async (issueData) => {
  await linkPlaneIssueToTicket(issueData);
  useAlert(t('TICKETS.PLANE_ISSUE_CREATED_AND_LINKED'));
};

const onPlaneIssueLinked = async (issueData) => {
  await linkPlaneIssueToTicket(issueData);
  useAlert(t('TICKETS.PLANE_ISSUE_LINKED_TO_TICKET'));
};

const linkPlaneIssueToTicket = async (issueData) => {
  isEscalating.value = true;
  const planeIssueId = issueData.id || issueData.issue_id;
  const planeIssueKey = issueData.key || issueData.issue_key || '';
  const planeProjectId = issueData.project_id || '';
  
  try {
    await store.dispatch('tickets/escalateToPlane', {
      ticketId: props.ticket.id,
      planeIssueId,
      planeIssueKey,
      planeProjectId,
    });
    
    emit('escalated', { planeIssueId, planeIssueKey, planeProjectId });
    onClose();
  } catch (error) {
    console.error('Error linking Plane issue to ticket:', error);
    useAlert(t('TICKETS.ESCALATE_TO_PLANE_ERROR'));
  } finally {
    isEscalating.value = false;
  }
};

const onPlaneModalClose = () => {
  // Don't close the escalation modal when Plane modal closes
  // unless escalation is complete
};

const onClose = () => {
  emit('close');
};
</script>

<template>
  <Modal
    :show="true"
    :on-close="onClose"
    :close-on-backdrop-click="false"
  >
    <div class="w-full max-w-4xl mx-auto">
      <div class="flex flex-col h-[700px]">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600">
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {{ $t('TICKETS.ESCALATE_TO_PLANE') }}
          </h2>
        </div>
        
        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-6">
          <div class="mb-6">
            <h3 class="text-sm font-medium text-n-slate-12 mb-2">
              {{ $t('TICKETS.ESCALATING_TICKET') }}
            </h3>
            <div class="bg-n-slate-2 rounded-lg p-4">
              <div class="flex items-center gap-3 mb-2">
                <div class="w-6 h-6 bg-purple-600 rounded text-white text-xs flex items-center justify-center font-bold">
                  T
                </div>
                <span class="font-medium">#{{ ticket.id }} - {{ ticket.title }}</span>
              </div>
              <p class="text-sm text-n-slate-11">{{ ticket.description || $t('TICKETS.NO_DESCRIPTION') }}</p>
            </div>
          </div>

          <!-- Plane Integration Component -->
          <div class="border border-n-weak rounded-lg">
            <CreateOrLinkIssue
              v-if="ticket.conversation?.id"
              :conversation-id="ticket.conversation.id"
              :title="generatePlaneTitle()"
              :description="generatePlaneDescription()"
              :show-header="false"
              @close="onPlaneModalClose"
              @issue-created="onPlaneIssueCreated"
              @issue-linked="onPlaneIssueLinked"
            />
            <div v-else class="p-4 text-center text-red-600">
              Error: No conversation found for this ticket
            </div>
          </div>
        </div>
        
        <!-- Footer -->
        <div class="flex items-center justify-end gap-3 p-6 border-t border-slate-200 dark:border-slate-600">
          <Button
            variant="ghost"
            @click="onClose"
            :disabled="isEscalating"
          >
            {{ $t('TICKETS.CANCEL') }}
          </Button>
        </div>
      </div>
    </div>
  </Modal>
</template>
