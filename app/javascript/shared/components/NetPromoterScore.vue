<script>
import { mapGetters } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import { NPS_RATINGS } from 'shared/constants/messages';
import { getContrastingTextColor } from '@chatwoot/utils';

export default {
  components: {
    Spinner,
  },
  props: {
    messageContentAttributes: {
      type: Object,
      default: () => {},
    },
    messageId: {
      type: Number,
      required: true,
    },
    message: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      ratings: NPS_RATINGS,
      selectedRating: null,
      isUpdating: false,
      feedback: '',
    };
  },
  computed: {
    ...mapGetters({ widgetColor: 'appConfig/getWidgetColor' }),
    isRatingSubmitted() {
      return this.messageContentAttributes?.nps_survey_response?.rating ||
             this.messageContentAttributes?.npsSurveyResponse?.rating;
    },
    isFeedbackSubmitted() {
      return this.messageContentAttributes?.nps_survey_response?.feedback_message ||
             this.messageContentAttributes?.npsSurveyResponse?.feedback_message;
    },
    isButtonDisabled() {
      // Only require feedback for negative scores (0-6, detractors)
      if (this.selectedRating !== null && this.selectedRating <= 6) {
        return !(this.selectedRating !== null && this.feedback);
      }
      // For neutral and positive scores, only rating is required
      return this.selectedRating === null;
    },
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    title() {
      return this.isRatingSubmitted
        ? this.$t('NPS.SUBMITTED_TITLE')
        : this.message || this.$t('NPS.TITLE');
    },
    ratingDescription() {
      // Remove the descriptions about being promoter/detractor/passive
      return '';
    },
  },

  mounted() {
    if (this.isRatingSubmitted) {
      const response = this.messageContentAttributes?.nps_survey_response || 
                      this.messageContentAttributes?.npsSurveyResponse || 
                      {};
      const { rating, feedback_message } = response;
      this.selectedRating = rating;
      this.feedback = feedback_message;
    }
  },

  methods: {
    buttonClass(rating) {
      return [
        { selected: rating.value === this.selectedRating },
        { disabled: this.isRatingSubmitted },
        { hover: this.isRatingSubmitted },
        'nps-button',
      ];
    },
    async onSubmit() {
      this.isUpdating = true;
      try {
        await this.$store.dispatch('message/update', {
          submittedValues: {
            nps_survey_response: {
              rating: this.selectedRating,
              feedback_message: this.feedback,
            },
          },
          messageId: this.messageId,
        });
      } catch (error) {
        // Ignore error
      } finally {
        this.isUpdating = false;
      }
    },

    selectRating(rating) {
      this.selectedRating = rating.value;
      
      // Auto-submit for positive ratings (7-10), require feedback for negative (0-6)
      if (this.selectedRating >= 7) {
        this.onSubmit();
      }
    },
  },
};
</script>

<template>
  <div
    class="w-full p-4 rounded-lg border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800"
  >
    <div class="mb-4">
      <h3 class="text-sm font-medium text-slate-800 dark:text-slate-200 mb-2">
        {{ title }}
      </h3>
    </div>

    <div v-if="!isRatingSubmitted" class="space-y-4">
      <!-- Rating Scale -->
      <div class="space-y-3">
        <div class="flex justify-between text-xs text-slate-600 dark:text-slate-400">
          <span>{{ $t('NPS.NOT_LIKELY') }}</span>
          <span>{{ $t('NPS.EXTREMELY_LIKELY') }}</span>
        </div>
        
        <div class="flex flex-col items-center space-y-2">
        <!-- First row: 0–5 -->
        <div class="flex space-x-1">
            <button
            v-for="rating in ratings.slice(0, 5)"
            :key="rating.value"
            :class="buttonClass(rating)"
            @click="selectRating(rating)"
            >
            {{ rating.value }}
            </button>
        </div>

        <!-- Second row: 6–10 -->
        <div class="flex space-x-1">
        <button
            v-for="rating in ratings.slice(5)"
            :key="rating.value"
            :class="buttonClass(rating)"
            @click="selectRating(rating)"
        >
            {{ rating.value }}
        </button>
        </div>
        </div>

      </div>

      <!-- Feedback - Only show for negative scores (0-6) -->
      <div v-if="selectedRating !== null && selectedRating <= 6" class="space-y-2">
        <label class="text-sm font-medium text-slate-700 dark:text-slate-300">
          {{ $t('NPS.FEEDBACK_LABEL') }}
        </label>
        <textarea
          v-model="feedback"
          :placeholder="$t('NPS.FEEDBACK_PLACEHOLDER')"
          class="w-full p-2 text-sm border border-slate-300 dark:border-slate-500 rounded-md bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          rows="3"
        />
      </div>

      <!-- Submit Button -->
      <div v-if="selectedRating !== null" class="flex justify-end">
        <button
          :disabled="isButtonDisabled || isUpdating"
          :style="{ background: widgetColor, color: textColor }"
          class="px-4 py-2 text-sm font-medium rounded-md disabled:opacity-50 disabled:cursor-not-allowed"
          @click="onSubmit"
        >
          <Spinner v-if="isUpdating" size="12px" />
          <span v-else>{{ $t('NPS.SUBMIT') }}</span>
        </button>
      </div>
    </div>

    <!-- Submitted State -->
    <div v-else class="space-y-3">
      <div class="flex items-center justify-between">
        <span class="text-sm text-slate-600 dark:text-slate-400">
          {{ $t('NPS.YOUR_RATING') }}:
        </span>
        <span class="text-lg font-semibold text-slate-800 dark:text-slate-200">
          {{ selectedRating }}/10
        </span>
      </div>
      
      <div v-if="feedback" class="space-y-1">
        <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
          {{ $t('NPS.YOUR_FEEDBACK') }}:
        </span>
        <p class="text-sm text-slate-600 dark:text-slate-400 bg-slate-50 dark:bg-slate-700 p-2 rounded">
          {{ feedback }}
        </p>
      </div>
      
      <p class="text-sm text-green-600 dark:text-green-400">
        {{ $t('NPS.THANK_YOU') }}
      </p>
    </div>
  </div>
</template>

<style scoped>
.nps-button {
  width: 2.2rem;
  height: 2.2rem;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid #cbd5e1;
  border-radius: 0.375rem;
  background-color: #ffffff;
  color: #374151;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0;
  padding: 0;
  cursor: pointer;
  flex-shrink: 0;
}

.nps-button:hover {
  background-color: #f1f5f9;
  border-color: #94a3b8;
  transform: translateY(-1px);
}

.nps-button.selected {
  background-color: #3b82f6;
  border-color: #3b82f6;
  color: #ffffff;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
}

.nps-button.disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

.nps-button.disabled:hover {
  background-color: #ffffff;
}

/* Dark mode styles */
html.dark .nps-button {
  border-color: #64748b;
  background-color: #374151;
  color: #d1d5db;
}

html.dark .nps-button:hover {
  background-color: #4b5563;
}

html.dark .nps-button.disabled:hover {
  background-color: #374151;
}
</style>
