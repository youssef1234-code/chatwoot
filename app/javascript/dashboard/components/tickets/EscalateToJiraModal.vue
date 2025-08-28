<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CreateOrLinkIssue from 'dashboard/components/widgets/conversation/jira/CreateOrLinkIssue.vue';

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

const generateJiraTitle = () => {
  return `[Ticket #${props.ticket.id}] ${props.ticket.title}`;
};

const generateJiraDescription = () => {
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

const onJiraIssueCreated = async (issueData) => {
  await linkJiraIssueToTicket(issueData.key);
  useAlert(t('TICKETS.JIRA_ISSUE_CREATED_AND_LINKED'));
};

const onJiraIssueLinked = async (issueData) => {
  await linkJiraIssueToTicket(issueData.key);
  useAlert(t('TICKETS.JIRA_ISSUE_LINKED_TO_TICKET'));
};

const linkJiraIssueToTicket = async (jiraIssueKey) => {
  isEscalating.value = true;
  
  try {
    // Use the escalate endpoint to ensure proper activity message creation
    await store.dispatch('tickets/escalateToJira', {
      ticketId: props.ticket.id,
      jiraIssueKey
    });
    
    emit('escalated', { jiraIssueKey });
    onClose();
  } catch (error) {
    console.error('Error linking JIRA issue to ticket:', error);
    useAlert(t('TICKETS.ESCALATE_ERROR'));
  } finally {
    isEscalating.value = false;
  }
};

const onJiraModalClose = () => {
  // Don't close the escalation modal when JIRA modal closes
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
    :expandable="true"
  >
    <div class="w-full max-w-none mx-auto cw-expand-modal">
      <div class="flex flex-col h-[70vh] cw-expand-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600">
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {{ $t('TICKETS.ESCALATE_TO_JIRA') }}
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

          <!-- JIRA Integration Component -->
          <div class="border border-n-weak rounded-lg h-full overflow-hidden">
            <CreateOrLinkIssue
              v-if="ticket.conversation?.id"
              :conversation-id="ticket.conversation.id"
              :title="generateJiraTitle()"
              :description="generateJiraDescription()"
              :show-header="false"
              @close="onJiraModalClose"
              @issue-created="onJiraIssueCreated"
              @issue-linked="onJiraIssueLinked"
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

<style>
/* Only stretch the escalate modal internals when base Modal is expanded */
.modal-container.expanded .cw-expand-modal .cw-expand-col {
  height: 85vh;
  transition: height 280ms cubic-bezier(0.4, 0.0, 0.2, 1);
  will-change: height;
}

/* Base smooth transition for expandable elements */
.cw-expand-col {
  transition: height 280ms cubic-bezier(0.4, 0.0, 0.2, 1);
  will-change: height;
  transform: translateZ(0); /* Force GPU acceleration */
}
</style>