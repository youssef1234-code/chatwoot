<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import PlaneAPI from 'dashboard/api/integrations/plane';

const props = defineProps({
  projectId: {
    type: String,
    required: true,
  },
  issueId: {
    type: String,
    required: true,
  },
  issueKey: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const isLoading = ref(false);
const isAddingComment = ref(false);
const comments = ref([]);
const newComment = ref('');
const attachedFiles = ref([]);
const fileInput = ref(null);
const isUploadingAttachment = ref(false);

const currentUser = computed(() => store.getters.getCurrentUser);

const sortedComments = computed(() => {
  return [...comments.value].sort(
    (a, b) => new Date(a.created_at) - new Date(b.created_at)
  );
});

const hasComments = computed(() => comments.value.length > 0);

const loadComments = async () => {
  isLoading.value = true;
  try {
    const response = await PlaneAPI.getComments(
      props.projectId,
      props.issueId
    );
    if (response.data) {
      comments.value = response.data;
    }
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.COMMENTS.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const addComment = async () => {
  if (!newComment.value.trim() && attachedFiles.value.length === 0) return;

  isAddingComment.value = true;
  try {
    // Upload attachments first
    if (attachedFiles.value.length > 0) {
      isUploadingAttachment.value = true;
      for (const fileObj of attachedFiles.value) {
        try {
          await PlaneAPI.addAttachment(
            props.projectId,
            props.issueId,
            fileObj.file
          );
        } catch (err) {
          console.error('Failed to upload attachment:', err);
          useAlert(`Failed to upload ${fileObj.file.name}`);
        }
      }
      isUploadingAttachment.value = false;
    }

    // Add comment text if provided
    if (newComment.value.trim()) {
      // If we have attachments, append file names to the comment
      let commentBody = newComment.value.trim();
      if (attachedFiles.value.length > 0) {
        const fileNames = attachedFiles.value
          .map(f => f.file.name)
          .join(', ');
        commentBody += `\n\n📎 Attachments: ${fileNames}`;
      }

      const response = await PlaneAPI.addComment(
        props.projectId,
        props.issueId,
        commentBody
      );
      if (response.data) {
        comments.value.push(response.data);
      }
    } else if (attachedFiles.value.length > 0) {
      // Only attachments, no text - add a comment noting the attachments
      const fileNames = attachedFiles.value
        .map(f => f.file.name)
        .join(', ');
      const response = await PlaneAPI.addComment(
        props.projectId,
        props.issueId,
        `📎 Attachments uploaded: ${fileNames}`
      );
      if (response.data) {
        comments.value.push(response.data);
      }
    }

    newComment.value = '';
    attachedFiles.value = [];
    useAlert(t('INTEGRATION_SETTINGS.PLANE.COMMENTS.ADD_SUCCESS'));
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.COMMENTS.ADD_ERROR'));
  } finally {
    isAddingComment.value = false;
    isUploadingAttachment.value = false;
  }
};

const triggerFileSelect = () => {
  fileInput.value?.click();
};

const handleFileSelected = event => {
  const files = Array.from(event.target.files || []);
  const maxSize = 10 * 1024 * 1024; // 10MB per file

  files.forEach(file => {
    if (file.size > maxSize) {
      useAlert(`${file.name} exceeds 10MB limit`);
      return;
    }
    attachedFiles.value.push({
      file,
      name: file.name,
      size: file.size,
      preview: file.type.startsWith('image/')
        ? URL.createObjectURL(file)
        : null,
    });
  });

  // Reset input so the same file can be selected again
  if (fileInput.value) fileInput.value.value = '';
};

const removeFile = index => {
  const file = attachedFiles.value[index];
  if (file.preview) URL.revokeObjectURL(file.preview);
  attachedFiles.value.splice(index, 1);
};

const formatFileSize = bytes => {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

const canSubmit = computed(() => {
  return newComment.value.trim() || attachedFiles.value.length > 0;
});

const formatDate = dateString => {
  return new Date(dateString).toLocaleString();
};

const getAuthorInitial = comment => {
  const name = comment.actor || 'U';
  return name.charAt(0).toUpperCase();
};

const isFromChatwoot = comment => {
  const html = comment.comment_html || '';
  return (
    html.includes('Chatwoot Agent') || html.includes('Chatwoot Integration')
  );
};

const stripHtml = html => {
  if (!html) return '';
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
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
        :header-title="t('INTEGRATION_SETTINGS.PLANE.COMMENTS.TITLE')"
        :header-content="issueKey"
      >
        <div class="flex items-center mt-3">
          <FluentIcon
            icon="chat"
            size="20"
            class="text-indigo-600 dark:text-indigo-400 mr-2"
          />
          <span class="text-sm text-slate-600 dark:text-slate-400">
            {{ t('INTEGRATION_SETTINGS.PLANE.COMMENTS.SUBTITLE') }}
          </span>
        </div>
      </woot-modal-header>

      <!-- Comments List -->
      <div class="flex-1 overflow-y-auto max-h-96 px-8">
        <!-- Loading State -->
        <div
          v-if="isLoading"
          class="flex flex-col items-center justify-center py-12"
        >
          <div
            class="w-8 h-8 border-2 border-indigo-600 border-t-transparent rounded-full animate-spin"
          />
          <p class="mt-4 text-sm text-slate-600 dark:text-slate-400">
            {{ t('INTEGRATION_SETTINGS.PLANE.COMMENTS.LOADING') }}
          </p>
        </div>

        <!-- Empty State -->
        <div
          v-else-if="!hasComments"
          class="flex flex-col items-center justify-center py-12"
        >
          <FluentIcon
            icon="chat"
            size="48"
            class="text-slate-400 dark:text-slate-500 mb-4"
          />
          <h3
            class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2"
          >
            {{ t('INTEGRATION_SETTINGS.PLANE.COMMENTS.NO_COMMENTS') }}
          </h3>
          <p class="text-sm text-slate-600 dark:text-slate-400">
            {{ t('INTEGRATION_SETTINGS.PLANE.COMMENTS.NO_COMMENTS_DESC') }}
          </p>
        </div>

        <!-- Comments -->
        <div v-else class="space-y-4 py-4">
          <div
            v-for="comment in sortedComments"
            :key="comment.id"
            class="border border-slate-200 dark:border-slate-700 rounded-lg p-4"
            :class="{
              'bg-indigo-50 dark:bg-indigo-900/20 border-indigo-200 dark:border-indigo-800':
                isFromChatwoot(comment),
              'bg-white dark:bg-slate-800': !isFromChatwoot(comment),
            }"
          >
            <!-- Comment Header -->
            <div class="flex items-start justify-between mb-3">
              <div class="flex items-center">
                <div
                  class="flex items-center justify-center w-8 h-8 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full text-white text-sm font-medium mr-3 flex-shrink-0"
                >
                  {{ getAuthorInitial(comment) }}
                </div>
                <div>
                  <div class="flex items-center">
                    <span
                      class="font-medium text-sm text-slate-900 dark:text-slate-100"
                    >
                      {{ comment.actor || 'Unknown User' }}
                    </span>
                    <span
                      v-if="isFromChatwoot(comment)"
                      class="ml-2 px-2 py-0.5 bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 text-xs rounded-full font-medium"
                    >
                      Chatwoot
                    </span>
                  </div>
                  <span class="text-xs text-slate-500 dark:text-slate-400">
                    {{ formatDate(comment.created_at) }}
                  </span>
                </div>
              </div>
            </div>

            <!-- Comment Body -->
            <div
              class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-wrap leading-relaxed"
            >
              {{ stripHtml(comment.comment_html) }}
            </div>
          </div>
        </div>
      </div>

      <!-- Add Comment Form -->
      <div
        class="border-t border-slate-200 dark:border-slate-700 px-8 pb-8 pt-6"
      >
        <div class="space-y-4">
          <woot-input
            v-model="newComment"
            type="textarea"
            :rows="4"
            :placeholder="
              t('INTEGRATION_SETTINGS.PLANE.COMMENTS.PLACEHOLDER')
            "
            :label="t('INTEGRATION_SETTINGS.PLANE.COMMENTS.INPUT_LABEL')"
            class="w-full"
          />

          <!-- Attachment Area -->
          <div>
            <input
              ref="fileInput"
              type="file"
              multiple
              class="hidden"
              accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.rtf,.png,.jpg,.jpeg,.gif,.svg,.webp,.mp4,.mp3,.wav,.zip,.csv"
              @change="handleFileSelected"
            />
            <button
              type="button"
              class="inline-flex items-center gap-1.5 text-sm text-slate-600 dark:text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
              @click="triggerFileSelect"
            >
              <FluentIcon icon="attach" size="16" />
              Attach files
            </button>

            <!-- Attached Files Preview -->
            <div
              v-if="attachedFiles.length > 0"
              class="mt-2 space-y-2"
            >
              <div
                v-for="(fileObj, index) in attachedFiles"
                :key="index"
                class="flex items-center justify-between bg-slate-50 dark:bg-slate-800 rounded-lg px-3 py-2 border border-slate-200 dark:border-slate-700"
              >
                <div class="flex items-center gap-2 min-w-0">
                  <FluentIcon icon="document" size="16" class="text-slate-500 flex-shrink-0" />
                  <span class="text-sm text-slate-700 dark:text-slate-300 truncate">
                    {{ fileObj.name }}
                  </span>
                  <span class="text-xs text-slate-400 flex-shrink-0">
                    {{ formatFileSize(fileObj.size) }}
                  </span>
                </div>
                <button
                  type="button"
                  class="text-slate-400 hover:text-red-500 flex-shrink-0 ml-2"
                  @click="removeFile(index)"
                >
                  <FluentIcon icon="dismiss" size="14" />
                </button>
              </div>
            </div>
          </div>

          <!-- Footer -->
          <div
            class="flex items-center justify-between pt-4 border-t border-slate-200 dark:border-slate-700"
          >
            <div class="text-xs text-slate-500 dark:text-slate-400">
              {{ t('INTEGRATION_SETTINGS.PLANE.COMMENTS.POSTING_AS') }}
              <strong>{{ currentUser.name }}</strong>
              ({{ t('INTEGRATION_SETTINGS.PLANE.COMMENTS.CHATWOOT_AGENT') }})
            </div>
            <div class="flex space-x-3">
              <NextButton
                size="medium"
                variant="ghost"
                color-scheme="secondary"
                @click="closeModal"
              >
                {{ t('INTEGRATION_SETTINGS.PLANE.COMMENTS.CANCEL') }}
              </NextButton>
              <NextButton
                size="medium"
                variant="solid"
                color-scheme="primary"
                :is-loading="isAddingComment"
                :disabled="!canSubmit"
                @click="addComment"
              >
                <template v-if="isUploadingAttachment">
                  Uploading...
                </template>
                <template v-else>
                  {{ t('INTEGRATION_SETTINGS.PLANE.COMMENTS.SUBMIT') }}
                </template>
              </NextButton>
            </div>
          </div>
        </div>
      </div>
    </div>
  </woot-modal>
</template>
