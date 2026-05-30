<script setup>
import { ref, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import WhatsappBridgeAPI from 'dashboard/api/integrations/whatsappBridge';

import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextSpinner from 'dashboard/components-next/spinner/Spinner.vue';

defineProps({
  hookId: {
    type: [Number, String],
    required: true,
  },
});

const isLoading = ref(true);
const isSaving = ref(false);

const bridgeUrl = ref('');
const syncNumber = ref('');
const continueNumber = ref('');
const teamMembers = ref([]);

// New-member form
const newPhone = ref('');
const newName = ref('');
const newRole = ref('');

const loadSettings = async () => {
  try {
    const { data } = await WhatsappBridgeAPI.getSettings();
    bridgeUrl.value = data.bridge_url || '';
    syncNumber.value = data.sync_number || '';
    continueNumber.value = data.continue_number || '';
    teamMembers.value = data.team_members || [];
  } catch {
    // Settings may not exist yet; keep defaults.
  }
};

const saveConnection = async () => {
  isSaving.value = true;
  try {
    await WhatsappBridgeAPI.updateSettings({
      bridge_url: bridgeUrl.value,
      sync_number: syncNumber.value,
      continue_number: continueNumber.value,
    });
    useAlert('WhatsApp Bridge settings saved.');
  } catch {
    useAlert('Failed to save settings. Please try again.');
  } finally {
    isSaving.value = false;
  }
};

const addMember = async () => {
  if (!newPhone.value || !newRole.value) {
    useAlert('Phone number and role are required.');
    return;
  }
  try {
    const { data } = await WhatsappBridgeAPI.upsertTeamMember({
      phoneNumber: newPhone.value,
      role: newRole.value,
      displayName: newName.value,
    });
    teamMembers.value = data.team_members || [];
    newPhone.value = '';
    newName.value = '';
    newRole.value = '';
    useAlert('Team member saved.');
  } catch {
    useAlert('Failed to save team member.');
  }
};

const removeMember = async phone => {
  try {
    const { data } = await WhatsappBridgeAPI.deleteTeamMember(phone);
    teamMembers.value = data.team_members || [];
    useAlert('Team member removed.');
  } catch {
    useAlert('Failed to remove team member.');
  }
};

onMounted(async () => {
  await loadSettings();
  isLoading.value = false;
});
</script>

<template>
  <div
    class="mt-4 p-6 outline outline-1 outline-n-container bg-n-alpha-3 rounded-xl"
  >
    <h3 class="text-lg font-semibold text-n-slate-12 mb-1">
      WhatsApp Bridge Configuration
    </h3>
    <p class="text-sm text-n-slate-11 mb-6">
      Configure the bridge connection, the sync and continue numbers, and the
      team members whose WhatsApp messages should be tagged with a name and role.
    </p>

    <div v-if="isLoading" class="flex items-center justify-center py-8 gap-2">
      <NextSpinner :size="20" />
      <span class="text-sm text-n-slate-11">Loading settings...</span>
    </div>

    <div v-else class="flex flex-col gap-6">
      <!-- Connection + numbers -->
      <div class="flex flex-col gap-4">
        <NextInput
          v-model="bridgeUrl"
          label="Bridge URL"
          placeholder="http://localhost:3100"
          message="Reachable from the Chatwoot server. Same host can use localhost:3100."
        />
        <div class="grid grid-cols-2 gap-4">
          <NextInput
            v-model="syncNumber"
            label="Sync number"
            placeholder="e.g. 201234567890"
            message="Used once to back-fill group history."
          />
          <NextInput
            v-model="continueNumber"
            label="Continue number"
            placeholder="e.g. 201234567890"
            message="Used for ongoing receiving and sending."
          />
        </div>
        <div class="flex justify-end">
          <NextButton
            label="Save Settings"
            :is-loading="isSaving"
            @click="saveConnection"
          />
        </div>
      </div>

      <!-- Team members -->
      <div>
        <label class="mb-1 block text-sm font-medium text-n-slate-12">
          Team Members
        </label>
        <p class="text-xs text-n-slate-10 mb-3">
          Members are matched by WhatsApp phone number. Their messages in synced
          groups are tagged with the configured display name and role.
        </p>

        <!-- Existing members -->
        <div v-if="teamMembers.length" class="flex flex-col gap-2 mb-4">
          <div
            v-for="member in teamMembers"
            :key="member.phone_number"
            class="flex items-center justify-between gap-2 p-2 rounded-lg bg-n-alpha-2"
          >
            <div class="flex flex-col min-w-0">
              <span class="text-sm text-n-slate-12 truncate">
                {{ member.display_name || member.phone_number }}
                <span class="text-n-slate-10">({{ member.role }})</span>
              </span>
              <span class="text-xs text-n-slate-10">{{
                member.phone_number
              }}</span>
            </div>
            <NextButton
              ghost
              ruby
              xs
              icon="i-lucide-trash-2"
              @click="removeMember(member.phone_number)"
            />
          </div>
        </div>
        <p v-else class="text-sm text-n-slate-10 mb-4">
          No team members configured yet.
        </p>

        <!-- Add member -->
        <div class="grid grid-cols-3 gap-2 items-end">
          <NextInput
            v-model="newPhone"
            label="Phone number"
            placeholder="201234567890"
          />
          <NextInput v-model="newName" label="Display name" placeholder="Name" />
          <NextInput v-model="newRole" label="Role" placeholder="Agent" />
        </div>
        <div class="flex justify-end mt-2">
          <NextButton
            faded
            blue
            icon="i-lucide-plus"
            label="Add member"
            @click="addMember"
          />
        </div>
      </div>
    </div>
  </div>
</template>
