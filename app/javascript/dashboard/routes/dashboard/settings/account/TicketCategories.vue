<template>
  <div class="flex flex-col h-full">
    <div class="flex items-center justify-end mb-6">
      <Button color="success" :loading="isLoading" @click="addCategory">
        <Icon icon="i-lucide-plus" class="w-4 h-4 mr-2" />
        {{ $t("TICKETS.TICKET_CATEGORIES.ADD_CATEGORY") }}
      </Button>
    </div>

    <div class="flex-1">
      <div v-if="categories.length === 0" class="text-center py-12">
        <Icon
          icon="i-lucide-tag"
          class="w-12 h-12 text-n-slate-6 mx-auto mb-4"
        />
        <h3 class="text-lg font-medium text-n-slate-12 mb-2">
          {{ $t("TICKETS.TICKET_CATEGORIES.EMPTY_STATE.TITLE") }}
        </h3>
        <p class="text-n-slate-10 mb-4">
          {{ $t("TICKETS.TICKET_CATEGORIES.EMPTY_STATE.MESSAGE") }}
        </p>
        <Button color="primary" @click="resetToDefaults">
          {{ $t("TICKETS.TICKET_CATEGORIES.RESET_TO_DEFAULTS") }}
        </Button>
      </div>

      <div v-else class="space-y-3">
        <div
          v-for="(category, index) in categories"
          :key="index"
          class="flex items-center justify-between p-4 bg-white dark:bg-n-slate-1 border border-n-weak rounded-lg hover:border-n-strong transition-colors"
        >
          <div class="flex items-center flex-1">
            <Icon icon="i-lucide-tag" class="w-5 h-5 text-n-slate-8 mr-3" />
            <input
              v-if="editingIndex === index"
              v-model="editingValue"
              type="text"
              class="flex-1 px-3 py-2 border border-n-weak rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              @keyup.enter="saveEdit(index)"
              @keyup.escape="cancelEdit"
              @blur="saveEdit(index)"
              ref="editInput"
            />
            <span v-else class="flex-1 text-n-slate-12 font-medium">
              {{ category }}
            </span>
          </div>

          <div class="flex items-center gap-2">
            <Button
              v-if="editingIndex !== index"
              variant="ghost"
              size="sm"
              @click="startEdit(index, category)"
            >
              <Icon icon="i-lucide-edit" class="w-4 h-4" />
            </Button>

            <Button
              v-if="editingIndex === index"
              variant="ghost"
              size="sm"
              color="success"
              @click="saveEdit(index)"
            >
              <Icon icon="i-lucide-check" class="w-4 h-4" />
            </Button>

            <Button
              v-if="editingIndex === index"
              variant="ghost"
              size="sm"
              color="danger"
              @click="cancelEdit"
            >
              <Icon icon="i-lucide-x" class="w-4 h-4" />
            </Button>

            <Button
              v-if="editingIndex !== index"
              variant="ghost"
              size="sm"
              color="danger"
              @click="removeCategory(index)"
            >
              <Icon icon="i-lucide-trash-2" class="w-4 h-4" />
            </Button>
          </div>
        </div>
      </div>
    </div>

    <div
      class="flex items-center justify-between pt-6 border-t border-n-weak mt-6"
    >
      <Button variant="outline" @click="resetToDefaults">
        {{ $t("TICKETS.TICKET_CATEGORIES.RESET_TO_DEFAULTS") }}
      </Button>

      <div class="flex gap-3">
        <Button
          variant="outline"
          @click="discardChanges"
          :disabled="!hasChanges"
        >
          {{ $t("SETTINGS.DISCARD_CHANGES") }}
        </Button>
        <Button
          color="success"
          :loading="isLoading"
          @click="saveCategories"
          :disabled="!hasChanges"
        >
          {{ $t("SETTINGS.SAVE_CHANGES") }}
        </Button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from "vue";
import { useI18n } from "vue-i18n";
import { useStore } from "vuex";
import { useAlert } from "dashboard/composables";

import Button from "dashboard/components-next/button/Button.vue";
import Icon from "dashboard/components-next/icon/Icon.vue";

const { t } = useI18n();
const store = useStore();

const categories = ref([]);
const originalCategories = ref([]);
const isLoading = ref(false);
const editingIndex = ref(-1);
const editingValue = ref("");

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

const hasChanges = computed(() => {
  return (
    JSON.stringify(categories.value) !==
    JSON.stringify(originalCategories.value)
  );
});

const defaultCategories = [
  "General Support",
  "Technical Issue",
  "Billing",
  "Feature Request",
  "Bug Report",
  "Account Management",
  "Sales Inquiry",
];

const loadCategories = () => {
  const accountCategories = currentAccount.value?.settings?.ticket_categories;
  if (accountCategories && accountCategories.length > 0) {
    categories.value = [...accountCategories];
    originalCategories.value = [...accountCategories];
  }
};

const addCategory = () => {
  categories.value.push("New Category");
  const newIndex = categories.value.length - 1;
  startEdit(newIndex, "New Category");
};

const removeCategory = (index) => {
  if (categories.value.length <= 1) {
    useAlert(t("TICKETS.TICKET_CATEGORIES.MINIMUM_ONE_CATEGORY"));
    return;
  }
  categories.value.splice(index, 1);
};

const startEdit = async (index, value) => {
  editingIndex.value = index;
  editingValue.value = value;

  await nextTick();
  const editInput = document.querySelector('input[ref="editInput"]');
  if (editInput) {
    editInput.focus();
    editInput.select();
  }
};

const saveEdit = (index) => {
  if (editingValue.value.trim() === "") {
    useAlert(t("TICKETS.TICKET_CATEGORIES.CATEGORY_REQUIRED"));
    return;
  }

  // Check for duplicates
  const isDuplicate = categories.value.some(
    (cat, i) =>
      i !== index &&
      cat.toLowerCase() === editingValue.value.trim().toLowerCase()
  );

  if (isDuplicate) {
    useAlert(t("TICKETS.TICKET_CATEGORIES.DUPLICATE_CATEGORY"));
    return;
  }

  categories.value[index] = editingValue.value.trim();
  cancelEdit();
};

const cancelEdit = () => {
  editingIndex.value = -1;
  editingValue.value = "";
};

const resetToDefaults = () => {
  categories.value = [...defaultCategories];
};

const discardChanges = () => {
  categories.value = [...originalCategories.value];
  cancelEdit();
};

const saveCategories = async () => {
  if (categories.value.length === 0) {
    useAlert(t("TICKETS.TICKET_CATEGORIES.MINIMUM_ONE_CATEGORY"));
    return;
  }

  // Deduplicate before saving
  const deduped = [...new Set(categories.value.filter(c => c && c.trim()))];
  categories.value = deduped;

  isLoading.value = true;
  try {
    await store.dispatch("accounts/update", {
      ticket_categories: categories.value,
    });

    // Refresh the account data from the accounts store
    const accountId = store.getters.getCurrentAccountId;
    await store.dispatch("accounts/get", accountId);

    // Also refresh the current user data to update the auth store
    await store.dispatch("validityCheck");

    originalCategories.value = [...categories.value];
    useAlert(t("TICKETS.TICKET_CATEGORIES.SAVED_SUCCESSFULLY"));
  } catch (error) {
    console.error("Failed to save ticket categories:", error);
    useAlert(t("TICKETS.TICKET_CATEGORIES.SAVE_ERROR"));
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  loadCategories();
});
</script>
