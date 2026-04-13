<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const emit = defineEmits(['close']);
const store = useStore();

const deploymentType = ref('data_center');
const siteUrl = ref('');
const email = ref('');
const apiToken = ref('');
const isSubmitting = ref(false);

const deploymentOptions = [
  { label: 'Jira Cloud', value: 'cloud' },
  { label: 'Jira Data Center', value: 'data_center' },
];

const isCloud = computed(() => deploymentType.value === 'cloud');

const tokenLabel = computed(() =>
  isCloud.value ? 'API Token' : 'Personal Access Token'
);

const canSubmit = computed(() => {
  if (!siteUrl.value || !apiToken.value) return false;
  if (isCloud.value && !email.value) return false;
  return true;
});

const siteUrlError = computed(() => {
  if (!siteUrl.value) return '';
  try {
    new URL(siteUrl.value);
    return '';
  } catch {
    return 'Please enter a valid URL';
  }
});

const submit = async () => {
  if (!canSubmit.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    const settings = {
      site_url: siteUrl.value.replace(/\/+$/, ''),
      api_token: apiToken.value,
      deployment_type: deploymentType.value,
    };
    if (isCloud.value) {
      settings.email = email.value;
    }

    await store.dispatch('integrations/createHook', {
      app_id: 'jira',
      settings,
    });
    useAlert('JIRA integration connected successfully!');
    emit('close');
  } catch (error) {
    const msg =
      error?.response?.data?.message || 'Failed to connect to JIRA';
    useAlert(msg);
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto integration-hooks">
    <woot-modal-header
      header-title="JIRA Service Management"
      header-content="Connect your JIRA instance to create and track issues directly from conversations."
    />
    <form class="w-full flex flex-col gap-4 px-8 pb-8" @submit.prevent="submit">
      <div>
        <label class="mb-1 block text-sm font-medium text-n-slate-12">
          Deployment Type
        </label>
        <ComboBox
          v-model="deploymentType"
          :options="deploymentOptions"
          placeholder="Select deployment type"
        />
      </div>

      <NextInput
        v-model="siteUrl"
        label="Site URL"
        placeholder="https://your-jira.atlassian.net"
        :message="siteUrlError"
        :message-type="siteUrlError ? 'error' : 'info'"
      />

      <NextInput
        v-if="isCloud"
        v-model="email"
        label="Email"
        type="email"
        placeholder="you@example.com"
      />

      <NextInput
        v-model="apiToken"
        :label="tokenLabel"
        type="password"
        :placeholder="isCloud ? 'Paste your API token' : 'Paste your Personal Access Token'"
      />

      <p class="text-xs text-n-slate-10 -mt-2">
        <template v-if="isCloud">
          Generate from
          <a
            href="https://id.atlassian.com/manage/api-tokens"
            target="_blank"
            rel="noopener noreferrer"
            class="text-n-brand underline"
          >id.atlassian.com</a>
        </template>
        <template v-else>
          Generate from JIRA → Profile → Personal Access Tokens
        </template>
      </p>

      <div class="flex justify-end gap-2 pt-2">
        <NextButton
          faded
          slate
          label="Cancel"
          @click.prevent="$emit('close')"
        />
        <NextButton
          type="submit"
          label="Connect"
          :disabled="!canSubmit"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
