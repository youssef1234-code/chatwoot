<template>
  <div class="jira-webhook-setup bg-n-subtle p-6 rounded-lg border border-n-weak mb-6">
    <div class="flex items-start gap-4">
      <div class="flex-shrink-0">
        <fluent-icon icon="webhook" class="text-n-primary" size="24" />
      </div>
      <div class="flex-1">
        <h3 class="text-lg font-semibold text-n-primary mb-2">
          {{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.TITLE') }}
        </h3>
        <p class="text-sm text-n-secondary mb-4">
          {{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.DESCRIPTION') }}
        </p>
        
        <div class="space-y-4">
          <div class="bg-n-background p-4 rounded border">
            <label class="block text-sm font-medium text-n-primary mb-2">
              {{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.WEBHOOK_URL') }}
            </label>
            <div class="flex items-center gap-2">
              <input
                ref="webhookUrlInput"
                :value="webhookUrl"
                readonly
                class="flex-1 px-3 py-2 border border-n-weak rounded text-sm bg-n-subtle"
              />
              <NextButton
                variant="outline"
                size="sm"
                @click="copyWebhookUrl"
              >
                <fluent-icon icon="copy" size="16" />
                {{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.COPY') }}
              </NextButton>
            </div>
          </div>
          
          <div class="text-sm text-n-secondary">
            <p class="font-medium mb-2">
              {{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.INSTRUCTIONS_TITLE') }}
            </p>
            <ol class="list-decimal list-inside space-y-1 ml-4">
              <li>{{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.STEP_1') }}</li>
              <li>{{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.STEP_2') }}</li>
              <li>{{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.STEP_3') }}</li>
              <li>{{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.STEP_4') }}</li>
              <li>{{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.STEP_5') }}</li>
            </ol>
          </div>
          
          <div class="bg-n-amber-4 border border-n-amber-6 rounded p-3">
            <div class="flex items-start gap-2">
              <fluent-icon icon="important" class="text-n-amber-12 mt-0.5" size="16" />
              <div class="text-sm text-n-amber-12">
                <p class="font-medium">{{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.NOTE_TITLE') }}</p>
                <p>{{ $t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.NOTE_DESCRIPTION') }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const currentAccountId = useMapGetter('getCurrentAccountId');
const webhookUrlInput = ref(null);

const webhookUrl = computed(() => {
  const accountId = currentAccountId.value;
  const baseUrl = window.location.origin;
  return `${baseUrl}/api/v1/accounts/${accountId}/integrations/jira/webhooks`;
});

const copyWebhookUrl = async () => {
  try {
    await navigator.clipboard.writeText(webhookUrl.value);
    useAlert(t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.COPIED_SUCCESS'));
  } catch (error) {
    // Fallback for browsers that don't support clipboard API
    webhookUrlInput.value?.select();
    document.execCommand('copy');
    useAlert(t('INTEGRATION_SETTINGS.JIRA.WEBHOOK_SETUP.COPIED_SUCCESS'));
  }
};
</script>
