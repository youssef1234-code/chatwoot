<template>
  <div v-if="showAudioHelp" class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
    <div class="flex">
      <div class="flex-shrink-0">
        <Icon icon="i-heroicons-exclamation-triangle" class="h-5 w-5 text-yellow-400" />
      </div>
      <div class="ml-3">
        <h3 class="text-sm font-medium text-yellow-800">
          {{ $t('PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.AUDIO_HELP.TITLE') }}
        </h3>
        <div class="mt-2 text-sm text-yellow-700">
          <p>{{ $t('PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.AUDIO_HELP.DESCRIPTION') }}</p>
          <ul class="list-disc list-inside mt-2 space-y-1">
            <li>{{ $t('PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.AUDIO_HELP.TIP_1') }}</li>
            <li>{{ $t('PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.AUDIO_HELP.TIP_2') }}</li>
            <li>{{ $t('PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.AUDIO_HELP.TIP_3') }}</li>
          </ul>
        </div>
        <div class="mt-4 flex space-x-2">
          <button
            @click="testAudio"
            class="bg-yellow-100 text-yellow-800 text-xs font-medium px-2.5 py-1.5 rounded hover:bg-yellow-200"
          >
            {{ $t('PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.AUDIO_HELP.TEST_BUTTON') }}
          </button>
          <button
            @click="dismissHelp"
            class="bg-yellow-100 text-yellow-800 text-xs font-medium px-2.5 py-1.5 rounded hover:bg-yellow-200"
          >
            {{ $t('PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.AUDIO_HELP.DISMISS_BUTTON') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';

const showAudioHelp = ref(false);

onMounted(() => {
  // Show help if user hasn't dismissed it and audio notifications are enabled
  const dismissed = localStorage.getItem('chatwoot_audio_help_dismissed');
  const urlParams = new URLSearchParams(window.location.search);
  const debugMode = urlParams.get('debug') === 'audio';
  
  if (!dismissed || debugMode) {
    showAudioHelp.value = true;
  }
});

const testAudio = async () => {
  try {
    if (window.ChatwootAudioTestUtil) {
      const success = await window.ChatwootAudioTestUtil.testAudioNotification();
      if (success) {
        useAlert('Audio notification test completed successfully!');
      } else {
        useAlert('Audio notification test failed. Check browser console for details.', { variant: 'warning' });
      }
    } else {
      // Fallback for when test utility is not available
      const helper = window.DashboardAudioNotificationHelper;
      if (helper && helper.playAudioAlert) {
        await helper.playAudioAlert();
        useAlert('Audio test completed!');
      } else {
        useAlert('Audio notification system not available', { variant: 'error' });
      }
    }
  } catch (error) {
    console.error('Audio test failed:', error);
    useAlert('Audio test failed. Check your browser settings and permissions.', { variant: 'error' });
  }
};

const dismissHelp = () => {
  showAudioHelp.value = false;
  localStorage.setItem('chatwoot_audio_help_dismissed', 'true');
  useAlert('Audio help dismissed. You can re-enable it by adding ?debug=audio to the URL.');
};
</script>
