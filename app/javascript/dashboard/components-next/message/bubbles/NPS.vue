<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';

const { contentAttributes, content, message } = useMessageContext();
const { t } = useI18n();

const response = computed(() => {
  // First check the message's nps_survey_response association
  if (message?.value?.nps_survey_response) {
    return message.value.nps_survey_response;
  }
  
  // Then check the submitted values in content attributes
  return contentAttributes.value?.submittedValues?.npsSurveyResponse || 
         contentAttributes.value?.submittedValues?.nps_survey_response || 
         {};
});

const isRatingSubmitted = computed(() => {
  return !!response.value.rating;
});

const rating = computed(() => {
  return response.value.rating || 0;
});

const npsCategory = computed(() => {
  if (rating.value >= 9) return 'Promoter';
  if (rating.value >= 7) return 'Passive';
  return 'Detractor';
});
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="nps">
    <h4>{{ content || t('CONVERSATION.NPS_REPLY_MESSAGE') }}</h4>
    <dl v-if="isRatingSubmitted" class="mt-4">
      <dt class="text-n-slate-11 italic">
        {{ t('CONVERSATION.RATING_TITLE') }}
      </dt>
      <dd class="flex items-center">
        <span class="text-lg font-semibold mr-2">{{ rating }}/10</span>
        <span class="text-sm text-n-slate-10">({{ npsCategory }})</span>
      </dd>

      <dt v-if="response.feedback_message || response.feedbackMessage" class="text-n-slate-11 italic mt-2">
        {{ t('CONVERSATION.FEEDBACK_TITLE') }}
      </dt>
      <dd v-if="response.feedback_message || response.feedbackMessage">
        {{ response.feedback_message || response.feedbackMessage }}
      </dd>
    </dl>
  </BaseBubble>
</template>
