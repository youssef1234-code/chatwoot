<template>
  <Modal :show="true" :on-close="onClose" :close-on-backdrop-click="false">
    <div class="w-full max-w-2xl mx-auto">
      <div class="flex flex-col h-[600px]">
        <!-- Header -->
        <div
          class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600"
        >
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {{ $t("TICKETS.CREATE_TICKET") }}
          </h2>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-6">
          <form @submit.prevent="createTicket" class="space-y-4">
            <!-- Title -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t("TICKETS.TRACKING.TITLE") }} *
              </label>
              <input
                v-model="ticketForm.title"
                type="text"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                :placeholder="$t('TICKETS.TRACKING.SEARCH_PLACEHOLDER')"
                required
              />
              <p v-if="errors.title" class="mt-1 text-sm text-red-600">
                {{ errors.title[0] }}
              </p>
            </div>

            <!-- Description -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t("TICKETS.DESCRIPTION") }}
              </label>
              <textarea
                v-model="ticketForm.description"
                rows="4"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                :placeholder="$t('TICKETS.DESCRIPTION_PLACEHOLDER')"
              ></textarea>
              <p v-if="errors.description" class="mt-1 text-sm text-red-600">
                {{ errors.description[0] }}
              </p>
            </div>

            <!-- Priority -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t("TICKETS.PRIORITY.LABEL") }}
              </label>
              <select
                v-model="ticketForm.priority"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
              >
                <option value="low">{{ $t("TICKETS.PRIORITY.LOW") }}</option>
                <option value="medium">
                  {{ $t("TICKETS.PRIORITY.MEDIUM") }}
                </option>
                <option value="high">{{ $t("TICKETS.PRIORITY.HIGH") }}</option>
                <option value="urgent">
                  {{ $t("TICKETS.PRIORITY.URGENT") }}
                </option>
              </select>
            </div>

            <!-- Category -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t("TICKETS.CATEGORY.LABEL") }}
              </label>
              <select
                v-model="ticketForm.category"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
              >
                <option value="">{{ $t("TICKETS.CATEGORY.SELECT") }}</option>
                <option
                  v-for="category in availableCategories"
                  :key="category"
                  :value="category"
                >
                  {{ category }}
                </option>
              </select>
              <p v-if="errors.category" class="mt-1 text-sm text-red-600">
                {{ errors.category[0] }}
              </p>
            </div>

            <!-- Selected Messages Preview -->
            <div v-if="selectedMessageIds.length > 0">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{
                  $t("TICKETS.SELECTED_MESSAGES_PREVIEW", {
                    count: selectedMessageIds.length,
                  })
                }}
              </label>
              <div
                class="max-h-40 overflow-y-auto border border-n-slate-6 rounded-md bg-n-slate-1"
              >
                <div
                  v-for="message in selectedMessagesPreview"
                  :key="message.id"
                  class="p-3 border-b border-n-slate-4 last:border-b-0"
                >
                  <div class="text-xs text-n-slate-10 mb-1">
                    {{ formatMessageSender(message) }} •
                    {{ formatDate(message.created_at) }}
                  </div>
                  <div class="text-sm text-n-slate-12 line-clamp-2">
                    {{ message.content || $t("TICKETS.NO_CONTENT") }}
                  </div>
                </div>
              </div>
            </div>

            <!-- AI Enhancement Option -->
            <div
              v-if="
                selectedMessageIds.length > 0 &&
                (!ticketForm.title.trim() || !ticketForm.description.trim())
              "
            >
              <Button
                variant="outline"
                color="blue"
                size="small"
                :loading="isGeneratingWithAI"
                :disabled="isLoading"
                @click="generateTitleAndDescriptionWithAI"
                class="w-full"
              >
                <Icon icon="i-lucide-sparkles" class="w-4 h-4 mr-2" />
                {{ $t("TICKETS.GENERATE_WITH_AI") }}
              </Button>
              <p class="mt-1 text-xs text-n-slate-10">
                {{ $t("TICKETS.GENERATE_WITH_AI_HELP") }}
              </p>
            </div>
          </form>
        </div>

        <!-- Footer -->
        <div
          class="flex justify-end gap-3 p-6 border-t border-slate-200 dark:border-slate-600"
        >
          <Button
            ghost
            slate
            :label="$t('TICKETS.CANCEL')"
            @click="onClose"
            :disabled="isLoading"
          />

          <Button
            blue
            :label="$t('TICKETS.CREATE_TICKET')"
            :loading="isLoading"
            :disabled="!ticketForm.title.trim() || !ticketForm.description.trim() || !ticketForm.category.trim()"
            @click="createTicket"
          />
        </div>
      </div>
    </div>
  </Modal>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { useAlert } from "dashboard/composables";
import Modal from "dashboard/components/Modal.vue";
import Button from "dashboard/components-next/button/Button.vue";
import Icon from "dashboard/components-next/icon/Icon.vue";
import OpenaiAPI from "dashboard/api/integrations/openapi";
import { useStoreGetters, useStore } from "dashboard/composables/store";

const getters = useStoreGetters();

const props = defineProps({
  conversationId: {
    type: [String, Number],
    required: true,
  },
  selectedMessageIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(["close", "created"]);

const store = useStore();
const { t } = useI18n();

// Get current user and conversation data
const currentUser = computed(() => store.getters.getCurrentUser);
const currentChat = computed(() => store.getters.getSelectedChat);

const ticketForm = ref({
  title: "",
  description: "",
  priority: "medium",
  category: "",
  jira_issue_key: "",
  assigned_agent_id: currentUser.value?.id || "",
  conversation_id: props.conversationId,
});

const isLoading = ref(false);
const isGeneratingWithAI = ref(false);
const errors = ref({});

const currentAccount = computed(() => {
  const accountId = store.getters.getCurrentAccountId;
  const accountFromAccountsStore =
    store.getters["accounts/getAccount"](accountId);
  if (
    accountFromAccountsStore &&
    Object.keys(accountFromAccountsStore).length > 0
  ) {
    return accountFromAccountsStore;
  }
});

// Get available categories from account settings
const availableCategories = computed(() => {
  return currentAccount.value?.settings?.ticket_categories || [];
});

const selectedMessagesPreview = computed(() => {
  const conversation = currentChat.value;
  if (!conversation || !conversation.messages) {
    return [];
  }

  return conversation.messages.filter((message) =>
    props.selectedMessageIds.includes(message.id)
  );
});

const formatMessageSender = (message) => {
  if (message.message_type === 0) {
    return message.sender?.name || t("TICKETS.CUSTOMER");
  }
  return message.sender?.name || t("TICKETS.AGENT");
};

const formatDate = (dateString) => {
  return new Date(dateString).toLocaleString();
};

const createTicket = async () => {
  if (!ticketForm.value.title.trim()) {
    return;
  }

  isLoading.value = true;
  errors.value = {};

  try {
    const ticketData = {
      ...ticketForm.value,
      message_ids: props.selectedMessageIds,
    };

    console.log('=== CREATE TICKET DEBUG ===');
    console.log('Props conversationId:', props.conversationId);
    console.log('Ticket form conversation_id:', ticketForm.value.conversation_id);
    console.log('Final ticketData:', ticketData);

    await store.dispatch("tickets/create", ticketData);

    useAlert(t("TICKETS.CREATE_SUCCESS"));
    emit("created");
    onClose();
  } catch (error) {
    console.error("Error creating ticket:", error);
    if (error.response?.data?.errors) {
      errors.value = error.response.data.errors;
    }
    useAlert(t("TICKETS.CREATE_ERROR"));
  } finally {
    isLoading.value = false;
  }
};

// AI generation function for ticket title and description
const generateTitleAndDescriptionWithAI = async () => {
  if (isGeneratingWithAI.value || props.selectedMessageIds.length === 0) return;

  isGeneratingWithAI.value = true;

  try {
    // Get OpenAI integration
    const integrations = getters["integrations/getAppIntegrations"].value;

    const openaiHook = integrations.find(
      (hook) => hook.id === "openai" && hook.enabled
    );

    if (!openaiHook) {
      throw new Error(t("TICKETS.AI_ENHANCEMENT.OPENAI_NOT_CONFIGURED"));
    }
    if (!openaiHook) {
      throw new Error(t("TICKETS.AI_ENHANCEMENT.OPENAI_NOT_CONFIGURED"));
    }

    // Get selected messages content
    const conversation = currentChat.value;
    const selectedMessages =
      conversation.messages?.filter((message) =>
        props.selectedMessageIds.includes(message.id)
      ) || [];

    if (selectedMessages.length === 0) {
      throw new Error(t("TICKETS.AI_ENHANCEMENT.NO_MESSAGES_ERROR"));
    }

    // Format messages for AI
    const messagesContent = selectedMessages
      .map((message) => {
        const sender = message.message_type === 0 ? "Customer" : "Agent";
        const senderName = message.sender?.name || "Unknown";
        return `${sender} (${senderName}): ${message.content}`;
      })
      .join("\n\n");

    // Generate with AI
    const enhancementOptions = [];
    if (!ticketForm.value.title.trim())
      enhancementOptions.push("improve_title");
    if (!ticketForm.value.description.trim())
      enhancementOptions.push("improve_description");

    const response = await OpenaiAPI.enhanceTicket({
      title: ticketForm.value.title || "",
      description: ticketForm.value.description || "",
      messages: messagesContent,
      enhancementOptions,
      hookId: openaiHook?.hooks[0]?.id,
    });

    // Parse response
    let aiData = response.data;
    if (typeof aiData === "string") {
      try {
        aiData = JSON.parse(aiData);
      } catch (e) {
        aiData = { description: aiData };
      }
    }

    // Handle nested message structure
    if (aiData.message) {
      if (typeof aiData.message === "string") {
        try {
          aiData = JSON.parse(aiData.message);
        } catch (e) {
          aiData = { description: aiData.message };
        }
      } else {
        aiData = aiData.message;
      }
    }

    // Update form with AI-generated content
    if (aiData.title && !ticketForm.value.title.trim()) {
      ticketForm.value.title = aiData.title;
    }

    if (aiData.description && !ticketForm.value.description.trim()) {
      ticketForm.value.description = aiData.description;
    }

    useAlert(t("TICKETS.AI_GENERATION_SUCCESS"));
  } catch (error) {
    console.error("AI generation failed:", error);
    let errorMessage = error.message || t("TICKETS.AI_GENERATION_ERROR");
    if (error.response?.data?.error) {
      errorMessage = error.response.data.error;
    }
    useAlert(errorMessage);
  } finally {
    isGeneratingWithAI.value = false;
  }
};

const onClose = () => {
  emit("close");
};
</script>
