<template>
  <Modal :show="true" :on-close="onClose" :close-on-backdrop-click="false">
    <div class="w-full max-w-2xl mx-auto">
      <div class="flex flex-col h-[600px]">
        <!-- Header -->
        <div
          class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600"
        >
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {{ $t("TICKETS.EDIT_TICKET") }}
          </h2>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-6">
          <form @submit.prevent="updateTicket" class="space-y-4">
            <!-- Title -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t("TICKETS.TRACKING.TITLE") }} *
              </label>
              <input
                v-model="ticketForm.title"
                type="text"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                :placeholder="$t('TICKETS.TRACKING.TITLE_PLACEHOLDER')"
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
              <p v-if="errors.priority" class="mt-1 text-sm text-red-600">
                {{ errors.priority[0] }}
              </p>
            </div>

            <!-- Status -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t("TICKETS.STATUS.LABEL") }}
              </label>
              <select
                v-model="ticketForm.status"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
              >
                <option value="open">{{ $t("TICKETS.STATUS.OPEN") }}</option>
                <option value="in_progress">
                  {{ $t("TICKETS.STATUS.IN_PROGRESS") }}
                </option>
                <option value="resolved">
                  {{ $t("TICKETS.STATUS.RESOLVED") }}
                </option>
                <option value="closed">
                  {{ $t("TICKETS.STATUS.CLOSED") }}
                </option>
              </select>
              <p v-if="errors.status" class="mt-1 text-sm text-red-600">
                {{ errors.status[0] }}
              </p>
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

            <!-- Assigned Agent -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t("TICKETS.ASSIGNED_AGENT") }}
              </label>
              <select
                v-model="ticketForm.assigned_agent_id"
                class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
              >
                <option value="">{{ $t("TICKETS.UNASSIGNED") }}</option>
                <option
                  v-for="agent in agents"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>
              <p
                v-if="errors.assigned_agent_id"
                class="mt-1 text-sm text-red-600"
              >
                {{ errors.assigned_agent_id[0] }}
              </p>
            </div>
          </form>
        </div>

        <!-- Footer -->
        <div
          class="flex items-center justify-end gap-3 p-6 border-t border-slate-200 dark:border-slate-600"
        >
          <Button variant="ghost" @click="onClose" :disabled="isLoading">
            {{ $t("TICKETS.CANCEL") }}
          </Button>
          <Button
            color-scheme="success"
            :is-loading="isLoading"
            @click="updateTicket"
          >
            {{ $t("TICKETS.UPDATE_TICKET") }}
          </Button>
        </div>
      </div>
    </div>
  </Modal>
</template>

<script setup>
import { ref, computed, onMounted, reactive } from "vue";
import { useStore } from "vuex";
import { useI18n } from "vue-i18n";
import { useAlert } from "dashboard/composables";
import Modal from "dashboard/components/Modal.vue";
import Button from "dashboard/components-next/button/Button.vue";
import JiraAPI from "dashboard/api/integrations/jira";

const props = defineProps({
  ticket: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(["close", "updated"]);

const { t } = useI18n();
const store = useStore();

const isLoading = ref(false);
const errors = ref({});
const availableJiraIssues = ref([]);
const isLoadingJiraIssues = ref(false);

// Initialize form with ticket data
const ticketForm = reactive({
  title: props.ticket.title || "",
  description: props.ticket.description || "",
  priority: props.ticket.priority || "medium",
  status: props.ticket.status || "open",
  category: props.ticket.category || "",
  assigned_agent_id: props.ticket.assigned_agent?.id || "",
  jira_issue_key: props.ticket.jira_issue_key || "",
});

const agents = computed(() => {
  return store.getters["agents/getAgents"];
});

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

// Load JIRA issues for the conversation
const loadJiraIssues = async () => {
  if (!props.ticket.conversation_id) return;

  isLoadingJiraIssues.value = true;
  try {
    const response = await JiraAPI.getLinkedIssues(
      props.ticket.conversation_id
    );
    availableJiraIssues.value = (response.data || []).map((issue) => ({
      key: issue.key,
      summary: issue.summary || issue.title,
      status: issue.status,
      url: issue.url,
    }));
  } catch (error) {
    console.error("Failed to load JIRA issues:", error);
    availableJiraIssues.value = [];
  } finally {
    isLoadingJiraIssues.value = false;
  }
};

const updateTicket = async () => {
  if (!ticketForm.title.trim()) {
    return;
  }

  isLoading.value = true;
  errors.value = {};

  try {
    await store.dispatch("tickets/updateTicket", {
      id: props.ticket.id,
      ...ticketForm,
    });

    useAlert(t("TICKETS.UPDATE_SUCCESS"));
    emit("updated");
    onClose();
  } catch (error) {
    console.error("Error updating ticket:", error);
    if (error.response?.data?.errors) {
      errors.value = error.response.data.errors;
    }
    useAlert(t("TICKETS.UPDATE_ERROR"));
  } finally {
    isLoading.value = false;
  }
};

const onClose = () => {
  emit("close");
};

onMounted(() => {
  // Load agents for assignment dropdown
  store.dispatch("agents/get").then(() => {
    console.log("=== AGENTS DEBUG ===");
    console.log("Available agents:", agents.value);
    console.log("Ticket assigned agent:", props.ticket.assigned_agent);
    console.log("Form assigned_agent_id:", ticketForm.assigned_agent_id);
  });
  loadJiraIssues();
});
</script>
