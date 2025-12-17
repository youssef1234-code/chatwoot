<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import MarkdownIt from 'markdown-it';
import DOMPurify from 'dompurify';

import FullEditor from './FullEditor.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  enabledMenuOptions: { type: Array, default: () => [] },
  autofocus: { type: Boolean, default: true },
});

const emit = defineEmits(['update:modelValue', 'input', 'blur', 'focus']);

const { t } = useI18n();

// Initialize markdown-it with GFM-like options (tables are enabled by default)
const md = new MarkdownIt({
  html: true,
  breaks: true,
  linkify: true,
  typographer: true,
});

// Editor mode: 'wysiwyg' | 'markdown' | 'split'
const editorMode = ref('wysiwyg');
const markdownContent = ref(props.modelValue || '');
const textareaRef = ref(null);

// Pre-process markdown to fix common table formatting issues
// Tables with blank lines between rows are converted to proper format
// But a blank line followed by non-table content ends the table
const preprocessMarkdown = content => {
  if (!content) return '';

  const lines = content.split('\n');
  const result = [];
  let tableBuffer = [];
  let blankLineBuffer = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmedLine = line.trim();
    const isTableRow = /^\|.+\|$/.test(trimmedLine);
    const isSeparatorRow = /^\|[\s\-:|]+\|$/.test(trimmedLine);
    const isEmptyLine = trimmedLine === '';

    if (isTableRow || isSeparatorRow) {
      // If we had blank lines buffered, they were between table rows - discard them
      blankLineBuffer = [];
      tableBuffer.push(trimmedLine);
    } else if (isEmptyLine && tableBuffer.length > 0) {
      // Blank line after table content - buffer it, might be between rows or end of table
      blankLineBuffer.push(line);
    } else {
      // Non-table, non-empty line - flush table and blank lines
      if (tableBuffer.length > 0) {
        result.push(tableBuffer.join('\n'));
        tableBuffer = [];
      }
      // Add blank lines back (they end the table)
      result.push(...blankLineBuffer);
      blankLineBuffer = [];
      result.push(line);
    }
  }

  // Don't forget remaining buffers
  if (tableBuffer.length > 0) {
    result.push(tableBuffer.join('\n'));
  }
  result.push(...blankLineBuffer);

  return result.join('\n');
};

// Sync model value with internal state
watch(
  () => props.modelValue,
  newValue => {
    if (newValue !== markdownContent.value) {
      markdownContent.value = newValue || '';
    }
  }
);

// Rendered HTML preview with sanitization
// Pre-processes content to fix common table formatting issues (blank lines between rows)
const renderedPreview = computed(() => {
  if (!markdownContent.value) return '';
  const processedContent = preprocessMarkdown(markdownContent.value);
  const rawHtml = md.render(processedContent);
  return DOMPurify.sanitize(rawHtml);
});

// Handle content update from WYSIWYG editor
const onWysiwygUpdate = content => {
  markdownContent.value = content;
  emit('update:modelValue', content);
  emit('input', content);
};

// Handle content update from markdown textarea
const onMarkdownInput = event => {
  const content = event.target.value;
  markdownContent.value = content;
  emit('update:modelValue', content);
  emit('input', content);
};

// Switch between editor modes
const setEditorMode = async mode => {
  editorMode.value = mode;
  if (mode === 'markdown' && textareaRef.value) {
    await nextTick();
    textareaRef.value.focus();
  }
};

// Check if mode is active
const isModeActive = mode => editorMode.value === mode;

// Handle blur and focus events
const onBlur = () => emit('blur');
const onFocus = () => emit('focus');
</script>

<template>
  <div class="article-markdown-editor">
    <!-- Mode Toggle Buttons -->
    <div
      class="flex items-center gap-1 mb-3 p-1 bg-slate-50 dark:bg-slate-800 rounded-lg w-fit"
    >
      <Button
        :label="t('HELP_CENTER.ARTICLE_EDITOR.MODE.WYSIWYG')"
        :variant="isModeActive('wysiwyg') ? 'solid' : 'ghost'"
        :color="isModeActive('wysiwyg') ? 'blue' : 'slate'"
        size="xs"
        @click="setEditorMode('wysiwyg')"
      />
      <Button
        :label="t('HELP_CENTER.ARTICLE_EDITOR.MODE.MARKDOWN')"
        :variant="isModeActive('markdown') ? 'solid' : 'ghost'"
        :color="isModeActive('markdown') ? 'blue' : 'slate'"
        size="xs"
        @click="setEditorMode('markdown')"
      />
      <Button
        :label="t('HELP_CENTER.ARTICLE_EDITOR.MODE.SPLIT')"
        :variant="isModeActive('split') ? 'solid' : 'ghost'"
        :color="isModeActive('split') ? 'blue' : 'slate'"
        size="xs"
        @click="setEditorMode('split')"
      />
    </div>

    <!-- WYSIWYG Mode -->
    <div v-show="editorMode === 'wysiwyg'" class="wysiwyg-editor-container">
      <FullEditor
        :model-value="markdownContent"
        :placeholder="placeholder"
        :enabled-menu-options="enabledMenuOptions"
        :autofocus="autofocus"
        @update:model-value="onWysiwygUpdate"
        @blur="onBlur"
        @focus="onFocus"
      />
    </div>

    <!-- Markdown Mode -->
    <div v-show="editorMode === 'markdown'" class="markdown-editor-container">
      <div class="markdown-editor-wrapper">
        <textarea
          ref="textareaRef"
          :value="markdownContent"
          :placeholder="placeholder"
          class="markdown-textarea"
          @input="onMarkdownInput"
          @blur="onBlur"
          @focus="onFocus"
        />
      </div>
      <div class="preview-panel">
        <div class="preview-header">
          <span class="preview-label">{{
            t('HELP_CENTER.ARTICLE_EDITOR.PREVIEW_LABEL')
          }}</span>
        </div>
        <div
          class="preview-content article-content prose dark:prose-invert"
          v-html="renderedPreview"
        />
      </div>
    </div>

    <!-- Split Mode -->
    <div v-show="editorMode === 'split'" class="split-editor-container">
      <div class="split-editor-wrapper">
        <textarea
          :value="markdownContent"
          :placeholder="placeholder"
          class="markdown-textarea"
          @input="onMarkdownInput"
          @blur="onBlur"
          @focus="onFocus"
        />
      </div>
      <div class="split-preview-panel">
        <div class="preview-header">
          <span class="preview-label">{{
            t('HELP_CENTER.ARTICLE_EDITOR.PREVIEW_LABEL')
          }}</span>
        </div>
        <div
          class="preview-content article-content prose dark:prose-invert"
          v-html="renderedPreview"
        />
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.article-markdown-editor {
  @apply w-full;
}

.wysiwyg-editor-container {
  @apply w-full;
}

.markdown-editor-container {
  @apply flex flex-col gap-4;
}

.markdown-editor-wrapper {
  @apply w-full;
}

.markdown-textarea {
  @apply w-full min-h-[300px] p-4 rounded-lg border border-slate-200 dark:border-slate-700;
  @apply bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-100;
  @apply font-mono text-sm leading-relaxed resize-y;
  @apply focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent;
}

.preview-panel {
  @apply w-full border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden;
}

.preview-header {
  @apply px-4 py-2 bg-slate-50 dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700;
}

.preview-label {
  @apply text-sm font-medium text-slate-600 dark:text-slate-400;
}

.preview-content {
  @apply p-4 min-h-[200px] max-h-[500px] overflow-y-auto;
  @apply bg-white dark:bg-slate-900;
}

.split-editor-container {
  @apply grid grid-cols-2 gap-4;
}

.split-editor-wrapper {
  @apply w-full;

  .markdown-textarea {
    @apply h-full min-h-[400px];
  }
}

.split-preview-panel {
  @apply w-full border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden;

  .preview-content {
    @apply min-h-[400px];
  }
}

// Prose styles for preview content
.preview-content {
  :deep(h1) {
    @apply text-2xl font-bold mb-4 mt-6 first:mt-0;
  }

  :deep(h2) {
    @apply text-xl font-semibold mb-3 mt-5;
  }

  :deep(h3) {
    @apply text-lg font-semibold mb-2 mt-4;
  }

  :deep(p) {
    @apply mb-4 leading-relaxed;
  }

  :deep(ul),
  :deep(ol) {
    @apply mb-4 pl-6;
  }

  :deep(ul) {
    @apply list-disc;
  }

  :deep(ol) {
    @apply list-decimal;
  }

  :deep(li) {
    @apply mb-1;
  }

  :deep(code) {
    @apply px-1.5 py-0.5 bg-slate-100 dark:bg-slate-800 rounded text-sm font-mono;
  }

  :deep(pre) {
    @apply p-4 bg-slate-100 dark:bg-slate-800 rounded-lg overflow-x-auto mb-4;

    code {
      @apply p-0 bg-transparent;
    }
  }

  :deep(blockquote) {
    @apply pl-4 border-l-4 border-slate-300 dark:border-slate-600 italic text-slate-600 dark:text-slate-400 mb-4;
  }

  :deep(a) {
    @apply text-woot-500 dark:text-woot-400 hover:underline;
  }

  :deep(img) {
    @apply max-w-full h-auto rounded-lg my-4;
  }

  :deep(table) {
    @apply w-full mb-4 text-sm;
    border-collapse: collapse;
    display: table;
  }

  :deep(thead) {
    @apply bg-slate-50 dark:bg-slate-800;
    display: table-header-group;
  }

  :deep(tbody) {
    @apply bg-white dark:bg-slate-900;
    display: table-row-group;
  }

  :deep(tr) {
    @apply border-b border-slate-200 dark:border-slate-700;
    display: table-row;
  }

  :deep(th) {
    @apply px-4 py-2 text-left font-semibold text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-700;
    display: table-cell;
  }

  :deep(td) {
    @apply px-4 py-2 text-left text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-700;
    display: table-cell;
  }

  :deep(hr) {
    @apply my-6 border-slate-200 dark:border-slate-700;
  }
}
</style>
