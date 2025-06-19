<script>
import { mapGetters } from 'vuex';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import MessagePreview from 'dashboard/components/widgets/conversation/MessagePreview.vue';
import { dynamicTime } from 'shared/helpers/timeHelper';

export default {
  name: 'StarredMessagesModal',
  components: {
    FluentIcon,
    MessagePreview,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: Number,
      required: true,
    },
  },
  emits: ['close', 'scrollToMessage'],
  data() {
    return {
      isLoading: false,
      searchQuery: '',
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
    }),
    starredMessages() {
      const messages = this.currentChat?.starredMessages || [];
      if (!this.searchQuery.trim()) {
        return messages;
      }
      
      // Filter messages based on search query
      const query = this.searchQuery.toLowerCase();
      return messages.filter(message => {
        const content = message.content?.toLowerCase() || '';
        const senderName = message.sender?.name?.toLowerCase() || '';
        return content.includes(query) || senderName.includes(query);
      });
    },
    hasStarredMessages() {
      return this.starredMessages.length > 0;
    },
    allStarredMessages() {
      return this.currentChat?.starredMessages || [];
    },
    hasAnyStarredMessages() {
      return this.allStarredMessages.length > 0;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.fetchStarredMessages();
          this.searchQuery = '';
        }
      },
    },
  },
  methods: {
    dynamicTime,
    async fetchStarredMessages() {
      if (this.isLoading) return;
      this.isLoading = true;
      try {
        await this.$store.dispatch('fetchStarredMessages', {
          conversationId: this.conversationId,
        });
      } catch (error) {
        // Handle error silently
      } finally {
        this.isLoading = false;
      }
    },
    closeModal() {
      this.$emit('close');
    },
    scrollToMessage(messageId) {
      this.$emit('scrollToMessage', messageId);
      this.closeModal();
    },
    async unstarMessage(messageId) {
      try {
        await this.$store.dispatch('unstarMessage', {
          conversationId: this.conversationId,
          messageId,
        });
      } catch (error) {
        // Handle error silently
      }
    },
    clearSearch() {
      this.searchQuery = '';
    },
  },
};
</script>

<template>
  <div>
    <transition name="modal-backdrop">
      <div v-if="show" class="modal-backdrop" @click="closeModal" />
    </transition>
    <transition name="modal-popup">
      <div v-if="show" class="starred-messages-popup">
        <div class="modal-header">
          <div class="header-content">
            <h2 class="header-title">
              {{ $t('CONVERSATION.STARRED_MESSAGES') }}
            </h2>
          </div>
          <button class="close-button" @click="closeModal">
            <FluentIcon icon="dismiss" size="20" />
          </button>
        </div>

        <div class="search-container">
          <div class="search-input-wrapper">
            <input
              v-model="searchQuery"
              type="text"
              class="search-input"
              :placeholder="$t('CONVERSATION.SEARCH_STARRED_MESSAGES')"
            />
          </div>
        </div>

        <div class="modal-content">
          <div v-if="isLoading" class="loading-state">
            <div class="spinner" />
            <p>{{ $t('CONVERSATION.LOADING_STARRED_MESSAGES') }}</p>
          </div>

          <div v-else-if="!hasAnyStarredMessages" class="empty-state">
            <FluentIcon icon="star-emphasis" size="48" />
            <h3>{{ $t('CONVERSATION.NO_STARRED_MESSAGES') }}</h3>
            <p>{{ $t('CONVERSATION.NO_STARRED_MESSAGES_DESC') }}</p>
          </div>

          <div
            v-else-if="searchQuery && !hasStarredMessages"
            class="empty-state"
          >
            <FluentIcon icon="search" size="48" />
            <h3>{{ $t('CONVERSATION.NO_SEARCH_RESULTS') }}</h3>
            <p>{{ $t('CONVERSATION.NO_SEARCH_RESULTS_DESC') }}</p>
          </div>

          <div v-else class="messages-list">
            <div
              v-for="message in starredMessages"
              :key="message.id"
              class="message-item"
            >
              <div class="message-header">
                <div class="sender-info">
                  <div class="sender-name">
                    {{ message.sender?.name || $t('CONVERSATION.BOT') }}
                  </div>
                  <div class="message-time">
                    {{ dynamicTime(message.starred_at || message.created_at) }}
                  </div>
                </div>
                <div class="message-actions">
                  <button
                    class="action-btn scroll-btn"
                    :title="$t('CONVERSATION.SCROLL_TO_MESSAGE')"
                    @click="scrollToMessage(message.id)"
                  >
                    <FluentIcon icon="chevron-up" size="16" />
                  </button>
                  <button
                    class="action-btn unstar-btn"
                    :title="$t('CONVERSATION.UNSTAR_MESSAGE')"
                    @click="unstarMessage(message.id)"
                  >
                    <FluentIcon icon="star-remove" size="16" />
                  </button>
                </div>
              </div>
              <div class="message-content" @click="scrollToMessage(message.id)">
                <MessagePreview :message="message" :show-message-type="false" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped lang="scss">
.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  z-index: 9998;
}

.starred-messages-popup {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 90%;
  max-width: 600px;
  max-height: 80vh;
  background-color: var(--color-background);
  border-radius: 12px;
  box-shadow:
    0 20px 25px -5px rgba(0, 0, 0, 0.1),
    0 10px 10px -5px rgba(0, 0, 0, 0.04);
  z-index: 9999;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 24px;
  border-bottom: 1px solid var(--color-border);
  background-color: var(--color-background);
}

.header-content {
  display: flex;
  align-items: center;
  gap: 12px;
}

.header-content .fluent-icon {
  color: var(--color-warning);
}

.header-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--color-body);
}

.close-button {
  padding: 8px;
  border: none;
  background: transparent;
  border-radius: 6px;
  color: var(--color-body);
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    background-color: var(--color-background-light);
  }
}

.search-container {
  padding: 16px 24px;
  border-bottom: 1px solid var(--color-border-light);
  background-color: var(--color-background);
}

.search-input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.search-icon {
  position: absolute;
  left: 14px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--color-body);
  opacity: 0.6;
  z-index: 1;
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 12px 44px 12px 44px;
  border: 1px solid var(--color-border);
  border-radius: 8px;
  background-color: var(--color-background);
  color: var(--color-body);
  font-size: 14px;
  outline: none;
  transition: all 0.2s ease;

  &:focus {
    border-color: var(--color-primary);
    box-shadow: 0 0 0 3px var(--color-primary-light);
  }

  &::placeholder {
    color: var(--color-body);
    opacity: 0.5;
  }
}

.clear-search-button {
  position: absolute;
  right: 12px;
  top: 50%;
  transform: translateY(-50%);
  padding: 6px;
  border: none;
  background: transparent;
  border-radius: 4px;
  color: var(--color-body);
  opacity: 0.6;
  cursor: pointer;
  transition: all 0.2s ease;

  &:hover {
    opacity: 1;
    background-color: var(--color-background-light);
  }
}

.modal-content {
  flex: 1;
  overflow-y: auto;
  min-height: 200px;
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
  text-align: center;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-border);
  border-top: 3px solid var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 16px;
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
  text-align: center;

  h3 {
    margin: 16px 0 8px;
    font-size: 16px;
    font-weight: 600;
    color: var(--color-body);
  }

  p {
    margin: 0;
    font-size: 14px;
    color: var(--color-body);
    opacity: 0.7;
  }
}

.messages-list {
  padding: 16px 24px;
}

.message-item {
  border-bottom: 1px solid var(--color-border-light);
  padding: 16px 0;

  &:last-child {
    border-bottom: none;
  }
}

.message-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 8px;
}

.sender-info {
  flex: 1;
  min-width: 0;
}

.sender-name {
  font-size: 14px;
  font-weight: 500;
  color: var(--color-body);
  margin-bottom: 4px;
}

.message-time {
  font-size: 12px;
  color: var(--color-body);
  opacity: 0.6;
}

.message-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.action-btn {
  padding: 8px;
  border: none;
  background: transparent;
  border-radius: 6px;
  color: var(--color-body);
  cursor: pointer;
  transition: all 0.2s ease;
  opacity: 0.7;

  &:hover {
    background-color: var(--color-background-light);
    opacity: 1;
  }

  &.scroll-btn {
    color: var(--color-primary);

    &:hover {
      background-color: var(--color-primary-light);
      color: var(--color-primary-dark);
    }
  }

  &.unstar-btn {
    color: var(--color-warning);

    &:hover {
      background-color: var(--color-warning-light);
      color: var(--color-warning-dark);
    }
  }
}

.message-content {
  cursor: pointer;
  padding: 8px 12px;
  border-radius: 8px;
  transition: all 0.2s ease;

  &:hover {
    background-color: var(--color-background-light);
  }

  // Override MessagePreview truncation for starred messages
  :deep(.overflow-hidden) {
    overflow: visible;
    white-space: normal;
    text-overflow: initial;
    display: -webkit-box;
    -webkit-line-clamp: 8; // Allow up to 4 lines
    -webkit-box-orient: vertical;
    overflow: hidden;
    line-height: 1.4;
    max-height: calc(1.4em * 8); // 8 lines worth of height
  }
}

// Transition animations
.modal-backdrop-enter-active,
.modal-backdrop-leave-active {
  transition: opacity 0.3s ease;
}

.modal-backdrop-enter-from,
.modal-backdrop-leave-to {
  opacity: 0;
}

.modal-popup-enter-active,
.modal-popup-leave-active {
  transition: all 0.3s ease;
}

.modal-popup-enter-from,
.modal-popup-leave-to {
  opacity: 0;
  transform: translate(-50%, -50%) scale(0.95);
}

@media (max-width: 768px) {
  .starred-messages-popup {
    width: 95%;
    max-height: 90vh;
  }
  
  .modal-header,
  .search-container,
  .messages-list {
    padding-left: 16px;
    padding-right: 16px;
  }
}
</style>
