<template>
  <Modal
    :show="true"
    :on-close="() => $emit('close')"
    size="medium"
  >
    <div class="p-6">
      <!-- Header -->
      <div class="flex items-center gap-3 mb-6">
        <Icon icon="i-lucide-sparkles" class="w-6 h-6 text-blue-600" />
        <div>
          <h2 class="text-xl font-semibold text-n-slate-12">
            {{ $t('TICKETS.AI_ENHANCEMENT.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-10 mt-1">
            {{ $t('TICKETS.AI_ENHANCEMENT.SUBTITLE') }}
          </p>
        </div>
      </div>
      <div class="space-y-6">
        <!-- Current Ticket Info -->
        <div class="p-4 bg-n-alpha-2 rounded-lg border border-n-weak">
          <h3 class="font-medium text-n-slate-12 mb-2">
            {{ $t('TICKETS.AI_ENHANCEMENT.CURRENT_TICKET') }}
          </h3>
          <div class="space-y-2">
            <div>
              <span class="text-sm font-medium text-n-slate-10">
                {{ $t('TICKETS.AI_ENHANCEMENT.CURRENT_TITLE') }}:
              </span>
              <span class="text-sm text-n-slate-11 ml-2">
                {{ ticket?.title || $t('TICKETS.UNTITLED') }}
              </span>
            </div>
            <div>
              <span class="text-sm font-medium text-n-slate-10">
                {{ $t('TICKETS.AI_ENHANCEMENT.CURRENT_DESCRIPTION') }}:
              </span>
              <p class="text-sm text-n-slate-11 mt-1">
                {{ ticket?.description || $t('TICKETS.AI_ENHANCEMENT.NO_DESCRIPTION') }}
              </p>
            </div>
          </div>
        </div>

        <!-- Enhancement Options -->
        <div>
          <h3 class="font-medium text-n-slate-12 mb-3">
            {{ $t('TICKETS.AI_ENHANCEMENT.ENHANCEMENT_OPTIONS') }}
          </h3>
          <div class="grid grid-cols-2 gap-3">
            <label
              v-for="option in enhancementOptions"
              :key="option.key"
              class="flex items-center gap-3 p-3 border border-n-weak rounded-lg cursor-pointer hover:border-blue-300 transition-colors theme-aware-selection"
              :class="{ 'border-blue-500 bg-blue-50 dark:bg-blue-900/20': selectedOptions.includes(option.key) }"
            >
              <input
                v-model="selectedOptions"
                type="checkbox"
                :value="option.key"
                class="text-blue-600 focus:ring-blue-500 focus:ring-2 rounded border-n-weak"
              />
              <div>
                <p class="text-sm font-medium text-n-slate-12">
                  {{ option.label }}
                </p>
                <p class="text-xs text-n-slate-9">
                  {{ option.description }}
                </p>
              </div>
            </label>
          </div>
        </div>

        <!-- AI Enhancement Results -->
        <div v-if="enhancementResults" class="space-y-4">
          <h3 class="font-medium text-n-slate-12">
            {{ $t('TICKETS.AI_ENHANCEMENT.RESULTS') }}
          </h3>

          <!-- Enhanced Title -->
          <div v-if="enhancementResults.title">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.AI_ENHANCEMENT.ENHANCED_TITLE') }}
            </label>
            <NextInput
              v-model="enhancementResults.title"
              :placeholder="$t('TICKETS.AI_ENHANCEMENT.TITLE_PLACEHOLDER')"
            />
          </div>

          <!-- Enhanced Description -->
          <div v-if="enhancementResults.description">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.AI_ENHANCEMENT.ENHANCED_DESCRIPTION') }}
            </label>
            <NextTextarea
              v-model="enhancementResults.description"
              :placeholder="$t('TICKETS.AI_ENHANCEMENT.DESCRIPTION_PLACEHOLDER')"
              rows="4"
            />
          </div>

          <!-- Suggested Priority -->
          <div v-if="enhancementResults.priority">
            <NextSelect
              v-model="enhancementResults.priority"
              :label="$t('TICKETS.AI_ENHANCEMENT.SUGGESTED_PRIORITY')"
              name="priority"
              :options="priorityOptions"
              :placeholder="$t('TICKETS.AI_ENHANCEMENT.SELECT_PRIORITY')"
            />
          </div>

          <!-- Suggested Labels -->
          <div v-if="enhancementResults.labels && enhancementResults.labels.length > 0">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.AI_ENHANCEMENT.SUGGESTED_LABELS') }}
            </label>
            <div class="flex flex-wrap gap-2">
              <span
                v-for="label in enhancementResults.labels"
                :key="label"
                class="px-3 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-200 text-sm rounded-full"
              >
                {{ label }}
              </span>
            </div>
          </div>

          <!-- Action Recommendations -->
          <div v-if="enhancementResults.recommendations && enhancementResults.recommendations.length > 0">
            <label class="block text-sm font-medium text-n-slate-10 mb-1">
              {{ $t('TICKETS.AI_ENHANCEMENT.RECOMMENDATIONS') }}
            </label>
            <ul class="space-y-1">
              <li
                v-for="recommendation in enhancementResults.recommendations"
                :key="recommendation"
                class="text-sm text-n-slate-11 flex items-start gap-2"
              >
                <Icon icon="i-lucide-arrow-right" class="w-4 h-4 text-blue-600 mt-0.5" />
                {{ recommendation }}
              </li>
            </ul>
          </div>
        </div>

        <!-- Loading State -->
        <div v-if="isEnhancing" class="text-center py-8">
          <div class="animate-spin w-8 h-8 border-2 border-blue-600 border-t-transparent rounded-full mx-auto mb-4"></div>
          <p class="text-sm text-n-slate-9">          {{ $t('TICKETS.AI_ENHANCEMENT.PROCESSING') }}
        </p>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-between mt-6 pt-4 border-t border-n-weak">
        <NextButton
          variant="outline"
          @click="$emit('close')"
        >
          {{ $t('TICKETS.AI_ENHANCEMENT.CANCEL') }}
        </NextButton>
        
        <div class="flex items-center gap-2">
          <NextButton
            v-if="!enhancementResults"
            color="blue"
            :is-loading="isEnhancing"
            :disabled="selectedOptions.length === 0"
            @click="enhanceWithAI"
          >
            <Icon icon="i-lucide-sparkles" class="w-4 h-4 mr-2" />
            {{ $t('TICKETS.AI_ENHANCEMENT.ENHANCE') }}
          </NextButton>
          
          <NextButton
            v-else
            color="blue"
            @click="applyEnhancements"
          >
            {{ $t('TICKETS.AI_ENHANCEMENT.APPLY') }}
          </NextButton>
        </div>
      </div>
        </div>
</div>
  </Modal>
</template>

<script>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextTextarea from 'v3/components/Form/Textarea.vue';
import NextSelect from 'v3/components/Form/Select.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

import OpenaiAPI from 'dashboard/api/integrations/openapi';

export default {
  name: 'AiEnhancementModal',
  components: {
    Modal,
    NextButton,
    NextInput,
    NextTextarea,
    NextSelect,
    Icon,
  },
  props: {
    ticket: {
      type: Object,
      required: true,
    },
  },
  emits: ['close', 'enhanced'],
  setup(props, { emit }) {
    const { t } = useI18n();
    const $store = useStore();
    const showAlert = useAlert();

    // State
    const isEnhancing = ref(false);
    const selectedOptions = ref(['improve_title', 'improve_description']);
    const enhancementResults = ref(null);

    // Computed
    const enhancementOptions = computed(() => [
      {
        key: 'improve_title',
        label: t('TICKETS.AI_ENHANCEMENT.OPTIONS.IMPROVE_TITLE'),
        description: t('TICKETS.AI_ENHANCEMENT.OPTIONS.IMPROVE_TITLE_DESC'),
      },
      {
        key: 'improve_description',
        label: t('TICKETS.AI_ENHANCEMENT.OPTIONS.IMPROVE_DESCRIPTION'),
        description: t('TICKETS.AI_ENHANCEMENT.OPTIONS.IMPROVE_DESCRIPTION_DESC'),
      },
      {
        key: 'suggest_priority',
        label: t('TICKETS.AI_ENHANCEMENT.OPTIONS.SUGGEST_PRIORITY'),
        description: t('TICKETS.AI_ENHANCEMENT.OPTIONS.SUGGEST_PRIORITY_DESC'),
      },
      {
        key: 'suggest_labels',
        label: t('TICKETS.AI_ENHANCEMENT.OPTIONS.SUGGEST_LABELS'),
        description: t('TICKETS.AI_ENHANCEMENT.OPTIONS.SUGGEST_LABELS_DESC'),
      },
      {
        key: 'action_recommendations',
        label: t('TICKETS.AI_ENHANCEMENT.OPTIONS.ACTION_RECOMMENDATIONS'),
        description: t('TICKETS.AI_ENHANCEMENT.OPTIONS.ACTION_RECOMMENDATIONS_DESC'),
      },
    ]);

    const priorityOptions = computed(() => [
      { label: t('TICKETS.PRIORITY.LOW'), value: 'low' },
      { label: t('TICKETS.PRIORITY.MEDIUM'), value: 'medium' },
      { label: t('TICKETS.PRIORITY.HIGH'), value: 'high' },
      { label: t('TICKETS.PRIORITY.URGENT'), value: 'urgent' },
    ]);

    // Methods
    const enhanceWithAI = async () => {
      isEnhancing.value = true;
      
      try {
        // Get the OpenAI hook ID from integrations
        const integrations = await $store.dispatch('integrations/get');
        const openaiHook = integrations?.find(hook => hook.app_id === 'openai' && hook.status === 'enabled');
        
        if (!openaiHook) {
          throw new Error(t('TICKETS.AI_ENHANCEMENT.OPENAI_NOT_CONFIGURED'));
        }

        // Get ONLY linked messages for the ticket (no old title/description sent)
        let messagesContent = '';
        try {
          const TicketsAPI = await import('dashboard/api/tickets');
          const messagesResponse = await TicketsAPI.default.getMessages(props.ticket.id);
          const linkedMessages = messagesResponse.data.messages || [];
          
          if (linkedMessages.length === 0) {
            throw new Error(t('TICKETS.AI_ENHANCEMENT.NO_MESSAGES_ERROR'));
          }
          
          // Extract ONLY the content of linked messages - no old title/description
          messagesContent = linkedMessages
            .filter(msg => msg.content && msg.content.trim())
            .map(msg => msg.content.trim())
            .join('\n\n');
            
          if (!messagesContent.trim()) {
            throw new Error('No text content found in linked messages.');
          }
        } catch (error) {
          console.error('Failed to fetch ticket messages:', error);
          throw error;
        }

        // Call the OpenAI API - send ONLY the linked messages content (no old values)
        const OpenaiAPI = await import('dashboard/api/integrations/openapi');
        const response = await OpenaiAPI.default.enhanceTicket({
          title: '', // Don't send existing title
          description: '', // Don't send existing description  
          messages: messagesContent, // Send ONLY the linked messages content
          enhancementOptions: selectedOptions.value,
          hookId: openaiHook.id,
        });
        
        // Parse the AI response
        let enhancedData;
        try {
          enhancedData = typeof response.data === 'string' ? JSON.parse(response.data) : response.data;
          if (enhancedData.message) {
            enhancedData = typeof enhancedData.message === 'string' ? JSON.parse(enhancedData.message) : enhancedData.message;
          }
        } catch (parseError) {
          // If parsing fails, treat the entire response as description
          const responseText = response.data?.message || response.data || 'AI enhancement completed';
          enhancedData = {
            description: responseText,
            title: selectedOptions.value.includes('improve_title') ? 
              responseText.split('\n')[0].substring(0, 100) : null,
          };
        }
        
        enhancementResults.value = {
          title: selectedOptions.value.includes('improve_title') ? (enhancedData.title || enhancedData.enhanced_title) : null,
          description: selectedOptions.value.includes('improve_description') ? (enhancedData.description || enhancedData.enhanced_description) : null,
          priority: selectedOptions.value.includes('suggest_priority') ? enhancedData.suggested_priority : null,
          labels: selectedOptions.value.includes('suggest_labels') ? enhancedData.suggested_labels : null,
          recommendations: selectedOptions.value.includes('action_recommendations') ? enhancedData.recommendations : null,
        };

        showAlert(t('TICKETS.AI_ENHANCEMENT.SUCCESS'));
      } catch (error) {
        console.error('AI enhancement failed:', error);
        showAlert(error.message || t('TICKETS.AI_ENHANCEMENT.ERROR'));
      } finally {
        isEnhancing.value = false;
      }
    };

    const applyEnhancements = () => {
      const enhancedData = {};
      
      if (enhancementResults.value.title) {
        enhancedData.title = enhancementResults.value.title;
      }
      
      if (enhancementResults.value.description) {
        enhancedData.description = enhancementResults.value.description;
      }
      
      if (enhancementResults.value.priority) {
        enhancedData.priority = enhancementResults.value.priority;
      }

      emit('enhanced', enhancedData);
    };

    return {
      // State
      isEnhancing,
      selectedOptions,
      enhancementResults,
      
      // Computed
      enhancementOptions,
      priorityOptions,
      
      // Methods
      enhanceWithAI,
      applyEnhancements,
    };
  },
};
</script>

<style scoped>
/* Animation for loading spinner */
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.animate-spin {
  animation: spin 1s linear infinite;
}

/* Theme-aware selection styling */
.theme-aware-selection {
  transition: all 0.2s ease-in-out;
}

.theme-aware-selection:hover {
  box-shadow: 0 1px 2px 0 rgb(0 0 0 / 0.05);
}

:global(.dark) .theme-aware-selection:hover {
  border-color: rgb(139 92 246);
}

.theme-aware-selection input[type="checkbox"] {
  background-color: white;
  border-color: var(--color-n-weak);
}

:global(.dark) .theme-aware-selection input[type="checkbox"] {
  background-color: var(--color-n-slate-2);
  border-color: var(--color-n-weak);
}

.theme-aware-selection input[type="checkbox"]:checked {
  background-color: rgb(139 92 246);
  border-color: rgb(139 92 246);
}

.theme-aware-selection input[type="checkbox"]:focus {
  outline: 2px solid rgb(139 92 246);
  outline-offset: 2px;
}

:global(.dark) .theme-aware-selection input[type="checkbox"]:focus {
  outline: 2px solid rgb(139 92 246);
  outline-offset: 2px;
}
</style>
