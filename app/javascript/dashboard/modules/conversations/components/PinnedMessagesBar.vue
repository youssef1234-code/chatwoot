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
  data() {
    return {
      showAllPinned: false,
    };
  },
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
    totalPinnedCount() {
      return this.pinnedMessages.length;
    },
    showPinnedBar() {
      return this.totalPinnedCount > 0;
    },
  },
  methods: {
    dynamicTime,
    scrollToMessage(messageId) {
      this.$emit('scrollToMessage', messageId);
    },
    toggleAllPinned() {
      this.showAllPinned = !this.showAllPinned;
    },
    closePinnedBar() {
      this.showAllPinned = false;
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
            <span v-if="totalPinnedCount > 1" class="pinned-count">
              {{ `+${totalPinnedCount - 1} ${$t('CONVERSATION.MORE')}` }}
            </span>
          </div>
          <MessagePreview
            :message="displayedMessage"
            :show-message-type="false"
            class="pinned-message-content"
          />
        </div>
        <div class="pinned-actions">
          <button
            v-if="totalPinnedCount > 1"
            class="action-button"
            @click="toggleAllPinned"
          >
            <FluentIcon icon="chevron-down" size="16" />
          </button>
          <button class="action-button close-button" @click="closePinnedBar">
            <FluentIcon icon="dismiss" size="16" />
          </button>
        </div>
      </div>

      <!-- Expanded view showing all pinned messages -->
      <div
        v-if="showAllPinned && totalPinnedCount > 1"
        class="all-pinned-messages"
      >
        <div
          v-for="message in pinnedMessages"
          :key="message.id"
          class="pinned-message-item"
          @click="scrollToMessage(message.id)"
        >
          <div class="message-sender">
            {{ message.sender?.name || $t('CONVERSATION.BOT') }}
          </div>
          <MessagePreview
            :message="message"
            :show-message-type="false"
            class="message-preview"
          />
          <div class="message-time">
            {{ dynamicTime(message.pinned_at || message.created_at) }}
          </div>
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
