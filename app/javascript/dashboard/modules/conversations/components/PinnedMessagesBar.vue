<script>
import { mapGetters } from 'vuex';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import MessagePreview from 'dashboard/components/widgets/conversation/MessagePreview.vue';
import { dynamicTime } from 'shared/helpers/timeHelper';

export default {
  name: 'PinnedMessagesBar',
  components: {
    FluentIcon,
    MessagePreview,
  },
  emits: ['scrollToMessage'],
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
    }),
    pinnedMessages() {
      return this.currentChat?.pinnedMessages || [];
    },
    displayedMessage() {
      if (this.pinnedMessages.length === 0) return null;
      return this.pinnedMessages[0]; // Show the most recent pinned message
    },
    showPinnedBar() {
      return this.pinnedMessages.length > 0;
    },
  },
  methods: {
    dynamicTime,
    scrollToMessage(messageId) {
      this.$emit('scrollToMessage', messageId);
    },
    async unpinMessage(messageId) {
      try {
        console.log('Unpinning message:', messageId, 'from conversation:', this.currentChat.id);
        await this.$store.dispatch('unpinMessage', {
          conversationId: this.currentChat.id,
          messageId: messageId,
        });
        this.$toast.success(this.$t('CONVERSATION.SUCCESS_UNPIN_MESSAGE'));
      } catch (error) {
        console.error('Failed to unpin message:', error);
        this.$toast.error(this.$t('CONVERSATION.FAIL_UNPIN_MESSAGE'));
      }
    },
  },
};
</script>

<template>
  <div>
    <div v-if="showPinnedBar" class="pinned-messages-bar">
      <!-- Main pinned message bar -->
      <div class="pinned-message-preview">
        <div class="pinned-icon">
          <FluentIcon icon="attach" size="16" />
        </div>
        <div
          class="pinned-content"
          @click="scrollToMessage(displayedMessage.id)"
        >
          <div class="pinned-label">
            <span class="pinned-text">{{
              $t('CONVERSATION.PINNED_MESSAGE')
            }}</span>
          </div>
          <MessagePreview
            :message="displayedMessage"
            :show-message-type="false"
            class="pinned-message-content"
          />
        </div>
        <div class="pinned-actions">
          <button 
            v-if="displayedMessage && displayedMessage.id"
            class="action-button close-button" 
            @click.stop="unpinMessage(displayedMessage.id)"
            :title="$t('CONVERSATION.CONTEXT_MENU.UNPIN')"
          >
            <FluentIcon icon="dismiss" size="16" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.pinned-messages-bar {
  border-bottom: 1px solid rgb(var(--color-ash-200));
  background-color: rgb(var(--color-ash-50));
  
  :global(.dark) & {
    border-bottom-color: rgb(var(--color-ash-200));
    background-color: rgb(var(--color-ash-50));
  }
}

.pinned-message-preview {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  cursor: pointer;

  &:hover {
    background-color: rgb(var(--color-ash-100));
    
    :global(.dark) & {
      background-color: rgb(var(--color-ash-100));
    }
  }
}

.pinned-icon {
  color: rgb(var(--color-primary-600));
  flex-shrink: 0;
}

.pinned-content {
  flex: 1;
  min-width: 0;
}

.pinned-label {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  font-weight: 500;
  color: rgb(var(--color-ash-700));
  margin-bottom: 4px;
  
  :global(.dark) & {
    color: rgb(var(--color-ash-700));
  }
}

.pinned-text {
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.pinned-count {
  color: rgb(var(--color-ash-600));
  
  :global(.dark) & {
    color: rgb(var(--color-ash-600));
  }
}

.pinned-message-content {
  font-size: 14px;
  color: rgb(var(--color-ash-800));
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  
  :global(.dark) & {
    color: rgb(var(--color-ash-800));
  }
}

.pinned-actions {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
}

.action-button {
  padding: 4px;
  border-radius: 4px;
  border: none;
  background: transparent;
  color: rgb(var(--color-ash-600));
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    background-color: rgb(var(--color-ash-100));
    color: rgb(var(--color-ash-800));
    
    :global(.dark) & {
      background-color: rgb(var(--color-ash-100));
      color: rgb(var(--color-ash-800));
    }
  }

  &.close-button:hover {
    background-color: rgb(var(--color-ruby-100));
    color: rgb(var(--color-ruby-600));
    
    :global(.dark) & {
      background-color: rgb(var(--color-ruby-100));
      color: rgb(var(--color-ruby-600));
    }
  }
  
  :global(.dark) & {
    color: rgb(var(--color-ash-600));
  }
}

.all-pinned-messages {
  border-top: 1px solid rgb(var(--color-ash-200));
  background-color: rgb(var(--color-ash-50));
  max-height: 256px;
  overflow-y: auto;
  
  :global(.dark) & {
    border-top-color: rgb(var(--color-ash-200));
    background-color: rgb(var(--color-ash-50));
  }
}

.pinned-message-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px;
  cursor: pointer;
  border-bottom: 1px solid rgb(var(--color-ash-100));

  &:hover {
    background-color: rgb(var(--color-ash-100));
    
    :global(.dark) & {
      background-color: rgb(var(--color-ash-100));
    }
  }

  &:last-child {
    border-bottom: none;
  }
  
  :global(.dark) & {
    border-bottom-color: rgb(var(--color-ash-100));
  }
}

.message-sender {
  font-size: 12px;
  font-weight: 500;
  color: rgb(var(--color-ash-700));
  flex-shrink: 0;
  width: 80px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  
  :global(.dark) & {
    color: rgb(var(--color-ash-700));
  }
}

.message-preview {
  flex: 1;
  min-width: 0;
  font-size: 14px;
  color: rgb(var(--color-ash-800));
  
  :global(.dark) & {
    color: rgb(var(--color-ash-800));
  }
}

.message-time {
  font-size: 12px;
  color: rgb(var(--color-ash-600));
  flex-shrink: 0;
  
  :global(.dark) & {
    color: rgb(var(--color-ash-600));
  }
}
</style>
