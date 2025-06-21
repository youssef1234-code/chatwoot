<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';
import JiraAPI from 'dashboard/api/integrations/jira';

const props = defineProps({
  issueKey: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const isLoading = ref(false);
const isAddingComment = ref(false);
const isUploadingAttachment = ref(false);
const comments = ref([]);
const newComment = ref('');
const attachments = ref([]);
const fileInput = ref(null);

const currentUser = computed(() => store.getters.getCurrentUser);

const sortedComments = computed(() => {
  return [...comments.value].sort((a, b) => new Date(a.created) - new Date(b.created));
});

const hasComments = computed(() => comments.value.length > 0);

const loadComments = async () => {
  isLoading.value = true;
  try {
    const response = await JiraAPI.getComments(props.issueKey);
    if (response.data) {
      comments.value = response.data;
    }
  } catch (error) {
    useAlert(t('INTEGRATION.JIRA.COMMENTS.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const addComment = async () => {
  if (!newComment.value.trim() && attachments.value.length === 0) return;
  
  isAddingComment.value = true;
  try {
    // Send just the comment text as expected by the backend
    const response = await JiraAPI.addComment(props.issueKey, newComment.value.trim());
    if (response.data) {
      comments.value.push(response.data);
      newComment.value = '';
      attachments.value = [];
      useAlert(t('INTEGRATION.JIRA.COMMENTS.ADD_SUCCESS'));
    }
  } catch (error) {
    useAlert(t('INTEGRATION.JIRA.COMMENTS.ADD_ERROR'));
  } finally {
    isAddingComment.value = false;
  }
};

const handleFileUpload = async (event) => {
  const files = Array.from(event.target.files);
  if (files.length === 0) return;

  isUploadingAttachment.value = true;
  try {
    for (const file of files) {
      const formData = new FormData();
      formData.append('file', file);
      
      const response = await JiraAPI.uploadAttachment(props.issueKey, formData);
      if (response.data) {
        attachments.value.push({
          id: response.data.id,
          filename: response.data.filename,
          size: response.data.size,
          mimeType: response.data.mimeType
        });
      }
    }
    useAlert(t('INTEGRATION.JIRA.ATTACHMENTS.UPLOAD_SUCCESS'));
  } catch (error) {
    useAlert(t('INTEGRATION.JIRA.ATTACHMENTS.UPLOAD_ERROR'));
  } finally {
    isUploadingAttachment.value = false;
    if (fileInput.value) fileInput.value.value = '';
  }
};

const removeAttachment = (index) => {
  attachments.value.splice(index, 1);
};

const formatDate = (dateString) => {
  return new Date(dateString).toLocaleString();
};

const formatFileSize = (bytes) => {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

const getAuthorDisplayName = (comment) => {
  if (comment.author?.chatwootAgent) {
    return `${comment.author.displayName} (Chatwoot Agent)`;
  }
  return comment.author?.displayName || 'Unknown User';
};

const isFromChatwoot = (comment) => {
  return comment.author?.chatwootAgent || comment.body?.includes('[Chatwoot Agent]');
};

onMounted(() => {
  loadComments();
});
</script>

<template>
  <!-- Blurred Background Overlay -->
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <!-- Backdrop with blur -->
    <div 
      class="absolute inset-0 bg-black/40 dark:bg-black/60 backdrop-blur-sm"
      @click="emit('close')"
    ></div>
    
    <!-- Modal Content -->
    <div class="relative bg-white dark:bg-slate-800 rounded-xl shadow-2xl w-full max-w-4xl max-h-[85vh] flex flex-col">
      <!-- Header -->
      <div class="flex items-center justify-between p-6 border-b border-gray-200 dark:border-slate-600 bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-slate-700 dark:to-slate-600 rounded-t-xl">
        <div class="flex items-center">
          <div class="flex items-center justify-center w-10 h-10 bg-blue-100 dark:bg-blue-900/50 rounded-lg mr-3">
            <!-- Fallback: Use emoji or text instead of icon -->
            <i class="ri-chat-3-line text-blue-600 dark:text-blue-400 text-lg"></i>
            <!-- Fallback option if icon doesn't work -->
            <span class="text-blue-600 dark:text-blue-400 text-lg font-bold" style="display: none;">💬</span>
          </div>
          <div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-slate-100">
              {{ t('INTEGRATION.JIRA.COMMENTS.TITLE') }}
            </h3>
            <p class="text-sm text-gray-600 dark:text-slate-400">{{ issueKey }}</p>
          </div>
        </div>
        <NextButton
          size="small"
          variant="ghost"
          color-scheme="secondary"
          class="hover:bg-gray-100 dark:hover:bg-slate-700"
          @click="emit('close')"
        >
          <!-- Fallback for close icon -->
          <i class="ri-close-line text-lg"></i>
          <span class="text-lg" style="display: none;">✕</span>
        </NextButton>
      </div>

      <!-- Comments List -->
      <div class="flex-1 overflow-y-auto p-6 bg-gray-50 dark:bg-slate-900">
        <div v-if="isLoading" class="text-center py-12">
          <div class="inline-block animate-spin rounded-full h-10 w-10 border-4 border-blue-600 dark:border-blue-400 border-t-transparent"></div>
          <p class="mt-4 text-sm text-gray-600 dark:text-slate-400">{{ t('INTEGRATION.JIRA.COMMENTS.LOADING') }}</p>
        </div>

        <div v-else-if="!hasComments" class="text-center py-12">
          <div class="flex items-center justify-center w-16 h-16 bg-gray-200 dark:bg-slate-600 rounded-full mx-auto mb-4">
            <!-- Fallback for empty state icon -->
            <i class="ri-chat-3-line text-gray-500 dark:text-slate-400 text-2xl"></i>
            <span class="text-gray-500 dark:text-slate-400 text-2xl" style="display: none;">💬</span>
          </div>
          <p class="text-gray-500 dark:text-slate-400 text-lg">{{ t('INTEGRATION.JIRA.COMMENTS.NO_COMMENTS') }}</p>
          <p class="text-gray-400 dark:text-slate-500 text-sm mt-2">Be the first to add a comment</p>
        </div>

        <div v-else class="space-y-4">
          <div
            v-for="comment in sortedComments"
            :key="comment.id"
            :class="{
              'bg-blue-50 dark:bg-blue-950/50': isFromChatwoot(comment),
              'bg-white dark:bg-slate-800': !isFromChatwoot(comment)
            }"
            class="rounded-lg p-4 shadow-sm border border-gray-200 dark:border-slate-600"
          >
            <div class="flex items-start justify-between mb-3">
              <div class="flex items-center">
                <!-- User Avatar with proper fallback -->
                <div class="flex items-center justify-center w-8 h-8 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-full text-white text-sm font-medium mr-3 flex-shrink-0">
                  {{ (comment.author?.displayName || 'U').charAt(0).toUpperCase() }}
                </div>
                <div>
                  <span class="font-medium text-sm text-gray-900 dark:text-slate-100">
                    {{ getAuthorDisplayName(comment) }}
                  </span>
                  <div class="flex items-center mt-1">
                    <span class="text-xs text-gray-500 dark:text-slate-400">
                      {{ formatDate(comment.created) }}
                    </span>
                    <span v-if="isFromChatwoot(comment)" class="ml-2 px-2 py-0.5 bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300 text-xs rounded-full">
                      Chatwoot
                    </span>
                  </div>
                </div>
              </div>
            </div>
            <div class="prose prose-sm max-w-none">
              <div class="text-sm text-gray-700 dark:text-slate-300 whitespace-pre-wrap leading-relaxed">{{ comment.body }}</div>
            </div>
            
            <!-- Comment Attachments -->
            <div v-if="comment.attachments && comment.attachments.length > 0" class="mt-3 pt-3 border-t border-gray-200 dark:border-slate-500">
              <div class="flex flex-wrap gap-2">
                <div
                  v-for="attachment in comment.attachments"
                  :key="attachment.id"
                  class="flex items-center px-3 py-2 bg-gray-100 dark:bg-slate-700 rounded-lg text-xs"
                >
                  <!-- Fallback for attachment icon -->
                  <i class="ri-attachment-line mr-2 text-gray-500 dark:text-slate-400"></i>
                  <span class="mr-2 text-gray-500 dark:text-slate-400" style="display: none;">📎</span>
                  <span class="text-gray-700 dark:text-slate-300">{{ attachment.filename }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Add Comment Form -->
      <div class="border-t border-gray-200 dark:border-slate-600 p-6 bg-white dark:bg-slate-800 rounded-b-xl">
        <!-- Attachments Preview -->
        <div v-if="attachments.length > 0" class="mb-4 p-3 bg-gray-100 dark:bg-slate-800 rounded-lg border border-gray-200 dark:border-slate-600">
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-gray-700 dark:text-slate-200">Attachments</span>
            <span class="text-xs text-gray-500 dark:text-slate-400">{{ attachments.length }} file(s)</span>
          </div>
          <div class="space-y-2">
            <div
              v-for="(attachment, index) in attachments"
              :key="index"
              class="flex items-center justify-between p-2 bg-white dark:bg-slate-700 rounded border border-gray-100 dark:border-slate-600"
            >
              <div class="flex items-center">
                <!-- Fallback for file icon -->
                <i class="ri-file-line mr-2 text-gray-500 dark:text-slate-400"></i>
                <span class="mr-2 text-gray-500 dark:text-slate-400" style="display: none;">📄</span>
                <span class="text-sm text-gray-700 dark:text-slate-200">{{ attachment.filename }}</span>
                <span class="text-xs text-gray-500 dark:text-slate-400 ml-2">({{ formatFileSize(attachment.size) }})</span>
              </div>
              <button
                type="button"
                class="text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 p-1"
                @click="removeAttachment(index)"
              >
                <!-- Fallback for close icon -->
                <i class="ri-close-line text-sm"></i>
                <span class="text-sm" style="display: none;">✕</span>
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-col space-y-4">
          <div class="relative">
            <textarea
              v-model="newComment"
              :placeholder="t('INTEGRATION.JIRA.COMMENTS.PLACEHOLDER')"
              class="w-full p-4 border border-gray-300 dark:border-slate-600 rounded-lg resize-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200 placeholder-gray-400 dark:placeholder-slate-500 bg-white dark:bg-slate-700 text-gray-900 dark:text-slate-100"
              rows="4"
            />
            <div class="absolute bottom-3 right-3 text-xs text-gray-400 dark:text-slate-500">
              {{ newComment.length }}/10000
            </div>
          </div>
          
          <!-- File Upload -->
          <div class="flex items-center gap-3">
            <input
              ref="fileInput"
              type="file"
              multiple
              accept=".jpg,.jpeg,.png,.pdf,.doc,.docx,.txt,.xlsx,.xls"
              class="hidden"
              @change="handleFileUpload"
            />
            <NextButton
              size="small"
              variant="ghost"
              color-scheme="secondary"
              :is-loading="isUploadingAttachment"
              @click="fileInput?.click()"
            >
              <!-- Fallback for attachment icon -->
              <i class="ri-attachment-line mr-2"></i>
              <span class="mr-2" style="display: none;">📎</span>
              {{ t('INTEGRATION.JIRA.ATTACHMENTS.UPLOAD') }}
            </NextButton>
            <span class="text-xs text-gray-500 dark:text-slate-400">
              {{ t('INTEGRATION.JIRA.ATTACHMENTS.SUPPORTED_FORMATS') }}
            </span>
          </div>
          
          <div class="flex justify-between items-center">
            <div class="text-xs text-gray-500 dark:text-slate-400">
              Comments will be posted as <strong>{{ currentUser.name }}</strong> (Chatwoot Agent)
            </div>
            <div class="flex space-x-3">
              <NextButton
                size="medium"
                variant="ghost"
                color-scheme="secondary"
                @click="emit('close')"
              >
                {{ t('INTEGRATION.JIRA.COMMENTS.CANCEL') }}
              </NextButton>
              <NextButton
                size="medium"
                variant="solid"
                color-scheme="primary"
                :is-loading="isAddingComment"
                :disabled="!newComment.trim() && attachments.length === 0"
                @click="addComment"
              >
                {{ t('INTEGRATION.JIRA.COMMENTS.SUBMIT') }}
              </NextButton>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Fallback CSS for when icons don't load */
.ri-chat-3-line:empty::before,
.ri-close-line:empty::before,
.ri-attachment-line:empty::before,
.ri-file-line:empty::before,
.ri-send-plane-line:empty::before {
  content: '';
}

/* Show emoji fallbacks if icons are empty */
.ri-chat-3-line:empty + span,
.ri-close-line:empty + span,
.ri-attachment-line:empty + span,
.ri-file-line:empty + span,
.ri-send-plane-line:empty + span {
  display: inline !important;
}

/* Ensure proper border for textarea */
textarea {
  border: 1px solid #d1d5db;
}

/* Ensure user avatar circles are properly sized and visible */
.w-8.h-8 {
  min-width: 2rem;
  min-height: 2rem;
}

.w-10.h-10 {
  min-width: 2.5rem;
  min-height: 2.5rem;
}
</style>