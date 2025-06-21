<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
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

const showModal = ref(true);

const closeModal = () => {
  showModal.value = false;
  emit('close');
};

onMounted(() => {
  loadComments();
});
</script>

<template>
  <woot-modal v-model:show="showModal" :on-close="closeModal" size="medium">
    <div class="flex flex-col h-auto overflow-hidden">
      <!-- Modal Header -->
      <woot-modal-header 
        :header-title="t('INTEGRATION.JIRA.COMMENTS.TITLE')"
        :header-content="issueKey"
      >
        <div class="flex items-center mt-3">
          <FluentIcon icon="chat" size="20" class="text-blue-600 dark:text-blue-400 mr-2" />
          <span class="text-sm text-slate-600 dark:text-slate-400">
            {{ t('INTEGRATION.JIRA.COMMENTS.SUBTITLE') }}
          </span>
        </div>
      </woot-modal-header>

      <!-- Comments List -->
      <div class="flex-1 overflow-y-auto max-h-96 px-8">
        <!-- Loading State -->
        <div v-if="isLoading" class="flex flex-col items-center justify-center py-12">
          <div class="w-8 h-8 border-2 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
          <p class="mt-4 text-sm text-slate-600 dark:text-slate-400">
            {{ t('INTEGRATION.JIRA.COMMENTS.LOADING') }}
          </p>
        </div>

        <!-- Empty State -->
        <div v-else-if="!hasComments" class="flex flex-col items-center justify-center py-12">
          <FluentIcon icon="chat" size="48" class="text-slate-400 dark:text-slate-500 mb-4" />
          <h3 class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2">
            {{ t('INTEGRATION.JIRA.COMMENTS.NO_COMMENTS') }}
          </h3>
          <p class="text-sm text-slate-600 dark:text-slate-400">
            {{ t('INTEGRATION.JIRA.COMMENTS.NO_COMMENTS_DESC') }}
          </p>
        </div>

        <!-- Comments -->
        <div v-else class="space-y-4 py-4">
          <div
            v-for="comment in sortedComments"
            :key="comment.id"
            class="border border-slate-200 dark:border-slate-700 rounded-lg p-4"
            :class="{
              'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800': isFromChatwoot(comment),
              'bg-white dark:bg-slate-800': !isFromChatwoot(comment)
            }"
          >
            <!-- Comment Header -->
            <div class="flex items-start justify-between mb-3">
              <div class="flex items-center">
                <div class="flex items-center justify-center w-8 h-8 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-full text-white text-sm font-medium mr-3 flex-shrink-0">
                  {{ (comment.author?.displayName || 'U').charAt(0).toUpperCase() }}
                </div>
                <div>
                  <div class="flex items-center">
                    <span class="font-medium text-sm text-slate-900 dark:text-slate-100">
                      {{ getAuthorDisplayName(comment) }}
                    </span>
                    <span v-if="isFromChatwoot(comment)" class="ml-2 px-2 py-0.5 bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300 text-xs rounded-full font-medium">
                      Chatwoot
                    </span>
                  </div>
                  <span class="text-xs text-slate-500 dark:text-slate-400">
                    {{ formatDate(comment.created) }}
                  </span>
                </div>
              </div>
            </div>

            <!-- Comment Body -->
            <div class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-wrap leading-relaxed">
              {{ comment.body }}
            </div>
            
            <!-- Comment Attachments -->
            <div v-if="comment.attachments && comment.attachments.length > 0" class="mt-3 pt-3 border-t border-slate-200 dark:border-slate-600">
              <div class="flex flex-wrap gap-2">
                <div
                  v-for="attachment in comment.attachments"
                  :key="attachment.id"
                  class="flex items-center px-3 py-2 bg-slate-100 dark:bg-slate-700 rounded-lg text-xs"
                >
                  <FluentIcon icon="attach" size="12" class="mr-2 text-slate-500 dark:text-slate-400" />
                  <span class="text-slate-700 dark:text-slate-300">{{ attachment.filename }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Add Comment Form -->
      <div class="border-t border-slate-200 dark:border-slate-700 px-8 pb-8 pt-6">
        <!-- Attachments Preview -->
        <div v-if="attachments.length > 0" class="mb-4 p-3 bg-slate-50 dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-600">
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
              {{ t('INTEGRATION.JIRA.ATTACHMENTS.TITLE') }}
            </span>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{ attachments.length }} {{ t('INTEGRATION.JIRA.ATTACHMENTS.FILES') }}
            </span>
          </div>
          <div class="space-y-2">
            <div
              v-for="(attachment, index) in attachments"
              :key="index"
              class="flex items-center justify-between p-2 bg-white dark:bg-slate-700 rounded border border-slate-100 dark:border-slate-600"
            >
              <div class="flex items-center">
                <FluentIcon icon="document" size="16" class="mr-2 text-slate-500 dark:text-slate-400" />
                <span class="text-sm text-slate-700 dark:text-slate-200">{{ attachment.filename }}</span>
                <span class="text-xs text-slate-500 dark:text-slate-400 ml-2">
                  ({{ formatFileSize(attachment.size) }})
                </span>
              </div>
              <button
                type="button"
                class="text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 p-1 rounded hover:bg-red-50 dark:hover:bg-red-900/20"
                @click="removeAttachment(index)"
              >
                <FluentIcon icon="delete" size="14" />
              </button>
            </div>
          </div>
        </div>

        <!-- Comment Input -->
        <div class="space-y-4">
          <woot-input
            v-model="newComment"
            type="textarea"
            :rows="4"
            :placeholder="t('INTEGRATION.JIRA.COMMENTS.PLACEHOLDER')"
            :label="t('INTEGRATION.JIRA.COMMENTS.INPUT_LABEL')"
            class="w-full"
          />
          
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
              <FluentIcon icon="attach" size="16" class="mr-2" />
              {{ t('INTEGRATION.JIRA.ATTACHMENTS.UPLOAD') }}
            </NextButton>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{ t('INTEGRATION.JIRA.ATTACHMENTS.SUPPORTED_FORMATS') }}
            </span>
          </div>
          
          <!-- Footer -->
          <div class="flex items-center justify-between pt-4 border-t border-slate-200 dark:border-slate-700">
            <div class="text-xs text-slate-500 dark:text-slate-400">
              {{ t('INTEGRATION.JIRA.COMMENTS.POSTING_AS') }} 
              <strong>{{ currentUser.name }}</strong> ({{ t('INTEGRATION.JIRA.COMMENTS.CHATWOOT_AGENT') }})
            </div>
            <div class="flex space-x-3">
              <NextButton
                size="medium"
                variant="ghost"
                color-scheme="secondary"
                @click="closeModal"
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
  </woot-modal>
</template>