<script>
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getContrastingTextColor } from '@chatwoot/utils';

export default {
  name: 'UserMessageBubble',
  props: {
    message: {
      type: String,
      default: '',
    },
    widgetColor: {
      type: String,
      default: '',
    },
  },
  setup() {
    const { formatMessage } = useMessageFormatter();
    return {
      formatMessage,
    };
  },
  computed: {
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
  },
};
</script>

<template>
  <div
    v-dompurify-html="formatMessage(message, false)"
    class="chat-bubble user message-text-content"
    :style="{ background: widgetColor, color: textColor }"
  />
</template>

<style lang="scss" scoped>
.message-text-content {
  unicode-bidi: plaintext;
  direction: auto;
}

.chat-bubble.user {
  unicode-bidi: plaintext;
  direction: auto;
}

.chat-bubble.user::v-deep {
  p, div, span {
    unicode-bidi: plaintext;
    direction: auto;
  }

  p code {
    @apply bg-n-alpha-2 dark:bg-n-alpha-1 text-white;
  }

  pre {
    @apply text-white bg-n-alpha-2 dark:bg-n-alpha-1;

    code {
      @apply bg-transparent text-white;
    }
  }

  blockquote {
    @apply bg-transparent border-n-slate-7 ltr:border-l-2 rtl:border-r-2 border-solid;

    p {
      @apply text-n-slate-5 dark:text-n-slate-12/90;
    }
  }
}
</style>
