<script>
import { mapGetters } from 'vuex';

import ChatAttachmentButton from 'widget/components/ChatAttachment.vue';
import ChatSendButton from 'widget/components/ChatSendButton.vue';
import configMixin from '../mixins/configMixin';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';

import EmojiInput from 'shared/components/emoji/EmojiInput.vue';

export default {
  name: 'ChatInputWrap',
  components: {
    ChatAttachmentButton,
    ChatSendButton,
    EmojiInput,
    FluentIcon,
    ResizableTextArea,
  },
  mixins: [configMixin],
  props: {
    onSendMessage: {
      type: Function,
      default: () => {},
    },
    onSendAttachment: {
      type: Function,
      default: () => {},
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    disabledMessage: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      userInput: '',
      showEmojiPicker: false,
      isFocused: false,
    };
  },

  computed: {
    ...mapGetters({
      widgetColor: 'appConfig/getWidgetColor',
      isWidgetOpen: 'appConfig/getIsWidgetOpen',
    }),
    showAttachment() {
      return this.hasAttachmentsEnabled && this.userInput.length === 0;
    },
    showSendButton() {
      return this.userInput.length > 0;
    },
  },
  watch: {
    isWidgetOpen(isWidgetOpen) {
      if (isWidgetOpen) {
        this.focusInput();
      }
    },
  },
  unmounted() {
    document.removeEventListener('keypress', this.handleEnterKeyPress);
  },
  mounted() {
    document.addEventListener('keypress', this.handleEnterKeyPress);
    if (this.isWidgetOpen) {
      this.focusInput();
    }
  },

  methods: {
    onBlur() {
      this.isFocused = false;
    },
    onFocus() {
      if (this.disabled) return;
      this.isFocused = true;
    },
    handleButtonClick() {
      if (this.disabled) return;
      if (this.userInput && this.userInput.trim()) {
        this.onSendMessage(this.userInput);
      }
      this.userInput = '';
      this.focusInput();
    },
    handleEnterKeyPress(e) {
      if (this.disabled) return;
      if (e.keyCode === 13 && !e.shiftKey) {
        e.preventDefault();
        this.handleButtonClick();
      }
    },
    toggleEmojiPicker() {
      if (this.disabled) return;
      this.showEmojiPicker = !this.showEmojiPicker;
    },
    hideEmojiPicker(e) {
      if (this.showEmojiPicker) {
        e.stopPropagation();
        this.toggleEmojiPicker();
      }
    },
    emojiOnClick(emoji) {
      if (this.disabled) return;
      this.userInput = `${this.userInput}${emoji} `;
    },
    onTypingOff() {
      this.toggleTyping('off');
    },
    onTypingOn() {
      this.toggleTyping('on');
    },
    toggleTyping(typingStatus) {
      this.$store.dispatch('conversation/toggleUserTyping', { typingStatus });
    },
    focusInput() {
      this.$refs.chatInput.focus();
    },
  },
};
</script>

<template>
  <div
    class="relative items-center flex ltr:pl-3 rtl:pr-3 ltr:pr-2 rtl:pl-2 rounded-[7px] transition-all duration-200 bg-n-background"
    :class="{
      '!shadow-[0_0_0_1px,0_0_2px_3px]': !disabled,
      '!shadow-n-brand dark:!shadow-n-brand': isFocused && !disabled,
      '!shadow-n-strong dark:!shadow-n-strong': !isFocused && !disabled,
  'opacity-50 !border !border-red-500 dark:!border-red-500 !shadow-none': disabled,
    }"
    @keydown.esc="hideEmojiPicker"
  >
    <!-- Disabled overlay -->
    <div
      v-if="disabled"
      class="absolute inset-0 bg-red-50 bg-opacity-90 dark:bg-red-900 backdrop-blur-sm rounded-[7px] !border !border-red-500 dark:!border-red-500 flex items-center justify-center z-10 cursor-not-allowed"
      :title="disabledMessage"
    >
  <div class="text-red-600 dark:text-red-400 text-sm font-medium text-center px-3" role="alert" aria-live="polite">
        {{ disabledMessage }}
      </div>
    </div>

    <ResizableTextArea
      id="chat-input"
      ref="chatInput"
      v-model="userInput"
      :rows="1"
      :aria-label="disabled ? disabledMessage : $t('CHAT_PLACEHOLDER')"
      :placeholder="disabled ? '' : $t('CHAT_PLACEHOLDER')"
      :disabled="disabled"
      class="user-message-input reset-base chat-input-enhanced"
      :class="{ 'cursor-not-allowed': disabled }"
      @typing-off="onTypingOff"
      @typing-on="onTypingOn"
      @focus="onFocus"
      @blur="onBlur"
    />
    <div class="flex items-center ltr:pl-2 rtl:pr-2">
      <ChatAttachmentButton
        v-if="showAttachment && !disabled"
        class="text-n-slate-12"
        :on-attach="onSendAttachment"
      />
      <button
        v-if="hasEmojiPickerEnabled && !disabled"
        class="flex items-center justify-center min-h-8 min-w-8"
        :aria-label="$t('EMOJI.ARIA_LABEL')"
        :disabled="disabled"
        @click="toggleEmojiPicker"
      >
        <FluentIcon
          icon="emoji"
          class="transition-all duration-150"
          :class="{
            'text-n-slate-12': !showEmojiPicker,
            'text-n-brand': showEmojiPicker,
          }"
        />
      </button>
      <EmojiInput
        v-if="showEmojiPicker && !disabled"
        v-on-clickaway="hideEmojiPicker"
        :on-click="emojiOnClick"
        @keydown.esc="hideEmojiPicker"
      />
      <ChatSendButton
        v-if="showSendButton && !disabled"
        :color="widgetColor"
        :disabled="disabled"
        @click="handleButtonClick"
      />
    </div>
  </div>
</template>

<style scoped lang="scss">
.emoji-dialog {
  @apply max-w-full ltr:right-5 rtl:right-[unset] rtl:left-5 -top-[302px] before:ltr:right-2.5 before:rtl:right-[unset] before:rtl:left-2.5;
}

.user-message-input {
  @apply border-none outline-none w-full placeholder:text-n-slate-10 resize-none h-8 min-h-8 max-h-60 py-1 px-0 my-2 bg-n-background text-n-slate-12 transition-all duration-200;
}

.chat-input-enhanced {
  unicode-bidi: plaintext;
  direction: auto;
}
</style>
