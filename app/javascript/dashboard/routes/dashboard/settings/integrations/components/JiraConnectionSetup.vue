<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required, url } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Modal from 'dashboard/components/Modal.vue';

const emit = defineEmits(['complete', 'cancel']);
const { t } = useI18n();

const isConnecting = ref(false);
const formData = ref({
  siteUrl: ''
});

// Custom validator for JIRA URLs
const jiraUrl = value => {
  if (!value) return true; // Let required handle empty values
  
  const normalizedUrl = value.toLowerCase();
  return normalizedUrl.includes('.atlassian.net') || 
         normalizedUrl.includes('.jira.com') ||
         normalizedUrl.match(/^https?:\/\/.+$/);
};

const rules = {
  siteUrl: { required, url, jiraUrl }
};

const v$ = useVuelidate(rules, formData);

const siteUrlError = computed(() => {
  if (v$.value.siteUrl.required.$invalid) {
    return t('INTEGRATION_SETTINGS.JIRA.SETUP.SITE_URL_REQUIRED');
  }
  if (v$.value.siteUrl.url.$invalid) {
    return t('INTEGRATION_SETTINGS.JIRA.SETUP.INVALID_URL');
  }
  if (v$.value.siteUrl.jiraUrl.$invalid) {
    return t('INTEGRATION_SETTINGS.JIRA.SETUP.INVALID_JIRA_URL');
  }
  return '';
});

const isSubmitDisabled = computed(() => {
  return v$.value.$invalid || isConnecting.value;
});

const connectToJira = async () => {
  await v$.value.$validate();
  if (v$.value.$error) return;

  try {
    isConnecting.value = true;
    
    // Instead of fetch, create a form and submit it to handle redirects properly
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/jira/configuration';
    
    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
    if (csrfToken) {
      const csrfInput = document.createElement('input');
      csrfInput.type = 'hidden';
      csrfInput.name = 'authenticity_token';
      csrfInput.value = csrfToken;
      form.appendChild(csrfInput);
    }
    
    // Add site URL
    const siteUrlInput = document.createElement('input');
    siteUrlInput.type = 'hidden';
    siteUrlInput.name = 'site_url';
    siteUrlInput.value = formData.value.siteUrl;
    form.appendChild(siteUrlInput);
    
    // Submit form to handle redirect
    document.body.appendChild(form);
    form.submit();
    
  } catch (error) {
    console.error('JIRA connection error:', error);
    useAlert(t('INTEGRATION_SETTINGS.JIRA.SETUP.CONNECTION_FAILED'));
    isConnecting.value = false;
  }
};

const onCancel = () => {
  emit('cancel');
};

const normalizeSiteUrl = () => {
  let url = formData.value.siteUrl.trim();
  
  if (!url) return;
  
  // Add https if no protocol
  if (!url.startsWith('http')) {
    url = `https://${url}`;
  }
  
  // Add .atlassian.net if just domain name
  if (!url.includes('.') || (!url.includes('.atlassian.net') && !url.includes('.jira.com'))) {
    const domain = url.replace(/^https?:\/\//, '');
    url = `https://${domain}.atlassian.net`;
  }
  
  formData.value.siteUrl = url;
};
</script>

<template>
  <Modal :show="true" @close="onCancel">
    <div class="p-6 max-w-md mx-auto">
      <div class="mb-6">
        <h2 class="text-xl font-semibold text-n-slate-12 mb-2">
          {{ $t('INTEGRATION_SETTINGS.JIRA.SETUP.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ $t('INTEGRATION_SETTINGS.JIRA.SETUP.DESCRIPTION') }}
        </p>
      </div>

      <form @submit.prevent="connectToJira">
        <div class="mb-4">
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            {{ $t('INTEGRATION_SETTINGS.JIRA.SETUP.SITE_URL_LABEL') }}
          </label>
          <Input
            v-model="formData.siteUrl"
            :placeholder="$t('INTEGRATION_SETTINGS.JIRA.SETUP.SITE_URL_PLACEHOLDER')"
            :error="siteUrlError"
            @blur="normalizeSiteUrl"
          />
          <p class="text-xs text-n-slate-11 mt-1">
            {{ $t('INTEGRATION_SETTINGS.JIRA.SETUP.SITE_URL_HELP') }}
          </p>
        </div>

        <div class="bg-blue-50 border border-blue-200 rounded-md p-3 mb-4">
          <h4 class="text-sm font-medium text-blue-800 mb-1">
            {{ $t('INTEGRATION_SETTINGS.JIRA.SETUP.OAUTH_INFO_TITLE') }}
          </h4>
          <p class="text-xs text-blue-700">
            {{ $t('INTEGRATION_SETTINGS.JIRA.SETUP.OAUTH_INFO_TEXT') }}
          </p>
        </div>

        <div class="flex justify-end gap-3">
          <Button
            ghost
            slate
            :label="$t('INTEGRATION_SETTINGS.JIRA.SETUP.CANCEL')"
            @click="onCancel"
          />
          <Button
            blue
            :label="$t('INTEGRATION_SETTINGS.JIRA.SETUP.CONNECT')"
            :loading="isConnecting"
            :disabled="isSubmitDisabled"
            type="submit"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
