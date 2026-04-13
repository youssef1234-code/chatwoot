<script>
import { ref, provide } from 'vue';
// composable
import { useConfig } from 'dashboard/composables/useConfig';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useAI } from 'dashboard/composables/useAI';
import { useMapGetter } from 'dashboard/composables/store';

// components
import ReplyBox from './ReplyBox.vue';
import Message from './Message.vue';
import NextMessageList from 'next/message/MessageList.vue';
import ConversationLabelSuggestion from './conversation/LabelSuggestion.vue';
import Banner from 'dashboard/components/ui/Banner.vue';
import PinnedMessagesBar from 'dashboard/modules/conversations/components/PinnedMessagesBar.vue';
import StarredMessagesModal from 'dashboard/modules/conversations/components/StarredMessagesModal.vue';
import MessageSelectionToolbar from 'dashboard/components/MessageSelectionToolbar.vue';
import CreateOrLinkIssue from './jira/CreateOrLinkIssue.vue';


// stores and apis
import { mapGetters } from 'vuex';

// mixins
import inboxMixin, { INBOX_FEATURES } from 'shared/mixins/inboxMixin';

// utils
import { emitter } from 'shared/helpers/mitt';
import { getTypingUsersText } from '../../../helper/commons';
import { calculateScrollTop } from './helpers/scrollTopCalculationHelper';
import { LocalStorage } from 'shared/helpers/localStorage';
import {
  filterDuplicateSourceMessages,
  getReadMessages,
  getUnreadMessages,
} from 'dashboard/helper/conversationHelper';

// constants
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { REPLY_POLICY } from 'shared/constants/links';
import wootConstants from 'dashboard/constants/globals';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { FEATURE_FLAGS } from '../../../featureFlags';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

export default {
  components: {
    Message,
    NextMessageList,
    ReplyBox,
    Banner,
    ConversationLabelSuggestion,
    PinnedMessagesBar,
    StarredMessagesModal,
    MessageSelectionToolbar,
    CreateOrLinkIssue,
  },
  mixins: [inboxMixin],
  props: {
    inboxId: {
      type: Number,
      default: null,
    },
    isInboxView: {
      type: Boolean,
      default: false,
    },
    isSelectionMode: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const isPopOutReplyBox = ref(false);
    const conversationPanelRef = ref(null);
    const { isEnterprise } = useConfig();

    const closePopOutReplyBox = () => {
      isPopOutReplyBox.value = false;
    };

    const showPopOutReplyBox = () => {
      isPopOutReplyBox.value = !isPopOutReplyBox.value;
    };

    const keyboardEvents = {
      Escape: {
        action: closePopOutReplyBox,
      },
    };

    useKeyboardEvents(keyboardEvents);

    const {
      isAIIntegrationEnabled,
      isLabelSuggestionFeatureEnabled,
      fetchIntegrationsIfRequired,
      fetchLabelSuggestions,
    } = useAI();

    const currentAccountId = useMapGetter('getCurrentAccountId');
    const isFeatureEnabledonAccount = useMapGetter(
      'accounts/isFeatureEnabledonAccount'
    );

    const showNextBubbles = isFeatureEnabledonAccount.value(
      currentAccountId.value,
      FEATURE_FLAGS.CHATWOOT_V4
    );

    provide('contextMenuElementTarget', conversationPanelRef);

    return {
      isEnterprise,
      isPopOutReplyBox,
      closePopOutReplyBox,
      showPopOutReplyBox,
      isAIIntegrationEnabled,
      isLabelSuggestionFeatureEnabled,
      fetchIntegrationsIfRequired,
      fetchLabelSuggestions,
      showNextBubbles,
      conversationPanelRef,
    };
  },
  data() {
    return {
      isLoadingPrevious: true,
      heightBeforeLoad: null,
      conversationPanel: null,
      hasUserScrolled: false,
      isProgrammaticScroll: false,
      messageSentSinceOpened: false,
      labelSuggestions: [],
      showStarredMessagesModal: false,
      selectedMessages: [],
      showCreateTicketModal: false,
      showLinkToExistingModal: false,
    };
  },

  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUserId: 'getCurrentUserID',
      listLoadingStatus: 'getAllMessagesLoaded',
      currentAccountId: 'getCurrentAccountId',
    }),
    isOpen() {
      return this.currentChat?.status === wootConstants.STATUS_TYPE.OPEN;
    },
    shouldShowLabelSuggestions() {
      return (
        this.isOpen &&
        this.isEnterprise &&
        this.isAIIntegrationEnabled &&
        !this.messageSentSinceOpened
      );
    },
    inboxId() {
      return this.currentChat.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
    typingUsersList() {
      const userList = this.$store.getters[
        'conversationTypingStatus/getUserList'
      ](this.currentChat.id);
      return userList;
    },
    isAnyoneTyping() {
      const userList = this.typingUsersList;
      return userList.length !== 0;
    },
    typingUserNames() {
      const userList = this.typingUsersList;
      if (this.isAnyoneTyping) {
        const [i18nKey, params] = getTypingUsersText(userList);
        return this.$t(i18nKey, params);
      }

      return '';
    },
    getMessages() {
      const messages = this.currentChat.messages || [];
      const sorted = [...messages].sort(
        (a, b) => a.created_at - b.created_at
      );
      if (this.isAWhatsAppChannel) {
        return filterDuplicateSourceMessages(sorted);
      }
      return sorted;
    },
    readMessages() {
      return getReadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    unReadMessages() {
      return getUnreadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    shouldShowSpinner() {
      return (
        (this.currentChat && this.currentChat.dataFetched === undefined) ||
        (!this.listLoadingStatus && this.isLoadingPrevious)
      );
    },
    conversationType() {
      const { additional_attributes: additionalAttributes } = this.currentChat;
      const type = additionalAttributes ? additionalAttributes.type : '';
      return type || '';
    },

    isATweet() {
      return this.conversationType === 'tweet';
    },
    getLastSeenAt() {
      const { contact_last_seen_at: contactLastSeenAt } = this.currentChat;
      return contactLastSeenAt;
    },

    // Check there is a instagram inbox exists with the same instagram_id
    hasDuplicateInstagramInbox() {
      const instagramId = this.inbox.instagram_id;
      const { additional_attributes: additionalAttributes = {} } = this.inbox;
      const instagramInbox =
        this.$store.getters['inboxes/getInstagramInboxByInstagramId'](
          instagramId
        );

      return (
        this.inbox.channel_type === INBOX_TYPES.FB &&
        additionalAttributes.type === 'instagram_direct_message' &&
        instagramInbox
      );
    },

    replyWindowBannerMessage() {
      if (this.isAWhatsAppChannel) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_CAN_REPLY');
      }
      if (this.isAPIInbox) {
        const { additional_attributes: additionalAttributes = {} } = this.inbox;
        if (additionalAttributes) {
          const {
            agent_reply_time_window_message: agentReplyTimeWindowMessage,
            agent_reply_time_window: agentReplyTimeWindow,
          } = additionalAttributes;
          return (
            agentReplyTimeWindowMessage ||
            this.$t('CONVERSATION.API_HOURS_WINDOW', {
              hours: agentReplyTimeWindow,
            })
          );
        }
        return '';
      }
      return this.$t('CONVERSATION.CANNOT_REPLY');
    },
    replyWindowLink() {
      if (this.isAFacebookInbox || this.isAnInstagramChannel) {
        return REPLY_POLICY.FACEBOOK;
      }
      if (this.isAWhatsAppCloudChannel) {
        return REPLY_POLICY.WHATSAPP_CLOUD;
      }
      if (!this.isAPIInbox) {
        return REPLY_POLICY.TWILIO_WHATSAPP;
      }
      return '';
    },
    replyWindowLinkText() {
      if (
        this.isAWhatsAppChannel ||
        this.isAFacebookInbox ||
        this.isAnInstagramChannel
      ) {
        return this.$t('CONVERSATION.24_HOURS_WINDOW');
      }
      if (!this.isAPIInbox) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_24_HOURS_WINDOW');
      }
      return '';
    },
    unreadMessageCount() {
      return this.currentChat.unread_count || 0;
    },
    unreadMessageLabel() {
      const count =
        this.unreadMessageCount > 9 ? '9+' : this.unreadMessageCount;
      const label =
        this.unreadMessageCount > 1
          ? 'CONVERSATION.UNREAD_MESSAGES'
          : 'CONVERSATION.UNREAD_MESSAGE';
      return `${count} ${this.$t(label)}`;
    },
    isInstagramDM() {
      return this.conversationType === 'instagram_direct_message';
    },
    inboxSupportsReplyTo() {
      const incoming = this.inboxHasFeature(INBOX_FEATURES.REPLY_TO);
      const outgoing =
        this.inboxHasFeature(INBOX_FEATURES.REPLY_TO_OUTGOING) &&
        !this.is360DialogWhatsAppChannel;

      return { incoming, outgoing };
    },
    hasStarredMessages() {
      return (
        this.currentChat?.starredMessages &&
        this.currentChat.starredMessages.length > 0
      );
    },
  },

  watch: {
    currentChat(newChat, oldChat) {
      if (newChat.id === oldChat.id) {
        return;
      }
      this.fetchAllAttachmentsFromCurrentChat();
      this.fetchSuggestions();
      this.messageSentSinceOpened = false;
      
      // Fetch starred and pinned messages for the new conversation
      if (newChat.id) {
        this.fetchStarredAndPinnedMessages(newChat.id);
      }
    },
    // Clear selected messages when selection mode is turned off
    isSelectionMode(newValue) {
      if (!newValue) {
        this.selectedMessages = [];
      }
    },
  },

  created() {
    emitter.on(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
    // when a new message comes in, we refetch the label suggestions
    emitter.on(BUS_EVENTS.FETCH_LABEL_SUGGESTIONS, this.fetchSuggestions);
    // when a message is sent we set the flag to true this hides the label suggestions,
    // until the chat is changed and the flag is reset in the watch for currentChat
    emitter.on(BUS_EVENTS.MESSAGE_SENT, () => {
      this.messageSentSinceOpened = true;
      // Mark messages as read when user sends a message (indicates active engagement)
      this.makeMessagesRead();
    });
  },

  mounted() {
    this.addScrollListener();
    this.fetchAllAttachmentsFromCurrentChat();
    this.fetchSuggestions();
    
    // Fetch starred and pinned messages for the current conversation
    if (this.currentChat?.id) {
      this.fetchStarredAndPinnedMessages(this.currentChat.id);
    }
    
    // Mark messages as read when conversation is opened/mounted
    this.$nextTick(() => {
      this.makeMessagesRead();
    });
  },

  unmounted() {
    this.removeBusListeners();
    this.removeScrollListener();
  },

  methods: {
    async fetchSuggestions() {
      // start empty, this ensures that the label suggestions are not shown
      this.labelSuggestions = [];

      if (this.isLabelSuggestionDismissed()) {
        return;
      }

      if (!this.isEnterprise) {
        return;
      }

      // method available in mixin, need to ensure that integrations are present
      await this.fetchIntegrationsIfRequired();

      if (!this.isLabelSuggestionFeatureEnabled) {
        return;
      }

      this.labelSuggestions = await this.fetchLabelSuggestions({
        conversationId: this.currentChat.id,
      });

      // once the labels are fetched, we need to scroll to bottom
      // but we need to wait for the DOM to be updated
      // so we use the nextTick method
      this.$nextTick(() => {
        // this param is added to route, telling the UI to navigate to the message
        // it is triggered by the SCROLL_TO_MESSAGE method
        // see setActiveChat on ConversationView.vue for more info
        const { messageId } = this.$route.query;

        // only trigger the scroll to bottom if the user has not scrolled
        // and there's no active messageId that is selected in view
        if (!messageId && !this.hasUserScrolled) {
          this.scrollToBottom();
        }
      });
    },
    isLabelSuggestionDismissed() {
      return LocalStorage.getFlag(
        LOCAL_STORAGE_KEYS.DISMISSED_LABEL_SUGGESTIONS,
        this.currentAccountId,
        this.currentChat.id
      );
    },
    fetchAllAttachmentsFromCurrentChat() {
      this.$store.dispatch('fetchAllAttachments', this.currentChat.id);
    },
    async fetchStarredAndPinnedMessages(conversationId) {
      try {
        await Promise.all([
          this.$store.dispatch('fetchStarredMessages', { conversationId }),
          this.$store.dispatch('fetchPinnedMessages', { conversationId }),
        ]);
      } catch (error) {
        // Silently handle error - starred/pinned messages are not critical
      }
    },
    removeBusListeners() {
      emitter.off(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
    },
    async onScrollToMessage({ messageId = '' } = {}) {
      if (!messageId) {
        this.scrollToBottom();
        return;
      }

      // First attempt - check if message is already in DOM
      let messageElement = document.getElementById('message' + messageId);
      if (messageElement) {
        this.scrollToMessageElement(messageElement);
        this.makeMessagesRead();
        return;
      }

      // Message not found - try to load older messages and retry
      await this.ensureMessageIsLoaded(messageId);
    },

    scrollToMessageElement(messageElement) {
      this.isProgrammaticScroll = true;
      messageElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
      
      // Highlight the message briefly
      messageElement.classList.add('message--highlighted');
      setTimeout(() => {
        messageElement.classList.remove('message--highlighted');
      }, 2000);
    },

    async ensureMessageIsLoaded(messageId, retryCount = 0) {
      const maxRetries = 5;
      const retryDelay = 300;

      // Check if we've exhausted retries
      if (retryCount >= maxRetries) {
        this.$toast.warning(this.$t('CONVERSATION.SCROLL_TO_MESSAGE_FAILED'));
        this.scrollToBottom();
        this.makeMessagesRead();
        return;
      }

      // Check if all messages are already loaded
      if (this.currentChat.allMessagesLoaded) {
        // All messages loaded but still can't find it - message might not exist
        if (retryCount === 0) {
          this.$toast.warning(this.$t('CONVERSATION.MESSAGE_NOT_FOUND'));
        }
        this.scrollToBottom();
        this.makeMessagesRead();
        return;
      }

      try {
        // Load more previous messages
        this.isLoadingPrevious = true;
        await this.$store.dispatch('fetchPreviousMessages', {
          conversationId: this.currentChat.id,
          before: this.currentChat.messages[0].id,
        });

        // Wait for DOM to update
        await this.$nextTick();
        await new Promise(resolve => setTimeout(resolve, retryDelay));

        // Check if message is now available
        const messageElement = document.getElementById('message' + messageId);
        if (messageElement) {
          this.scrollToMessageElement(messageElement);
          this.makeMessagesRead();
          return;
        }

        // Not found yet, retry
        await this.ensureMessageIsLoaded(messageId, retryCount + 1);
      } catch (error) {
        console.error('Error loading previous messages:', error);
        this.$toast.error(this.$t('CONVERSATION.SCROLL_TO_MESSAGE_ERROR'));
        this.scrollToBottom();
        this.makeMessagesRead();
      } finally {
        this.isLoadingPrevious = false;
      }
    },
    addScrollListener() {
      this.conversationPanel = this.$el.querySelector('.conversation-panel');
      this.setScrollParams();
      this.conversationPanel.addEventListener('scroll', this.handleScroll);
      this.$nextTick(() => this.scrollToBottom());
      this.isLoadingPrevious = false;
    },
    removeScrollListener() {
      this.conversationPanel.removeEventListener('scroll', this.handleScroll);
    },
    scrollToBottom() {
      this.isProgrammaticScroll = true;
      let relevantMessages = [];

      // label suggestions are not part of the messages list
      // so we need to handle them separately
      let labelSuggestions =
        this.conversationPanel.querySelector('.label-suggestion');

      // if there are unread messages, scroll to the first unread message
      if (this.unreadMessageCount > 0) {
        // capturing only the unread messages
        relevantMessages =
          this.conversationPanel.querySelectorAll('.message--unread');
      } else if (labelSuggestions) {
        // when scrolling to the bottom, the label suggestions is below the last message
        // so we scroll there if there are no unread messages
        // Unread messages always take the highest priority
        relevantMessages = [labelSuggestions];
      } else {
        // if there are no unread messages or label suggestion, scroll to the last message
        // capturing last message from the messages list
        relevantMessages = Array.from(
          this.conversationPanel.querySelectorAll('.message--read')
        ).slice(-1);
      }

      this.conversationPanel.scrollTop = calculateScrollTop(
        this.conversationPanel.scrollHeight,
        this.$el.scrollHeight,
        relevantMessages
      );
      
      // Mark messages as read when scrolling to bottom
      this.makeMessagesRead();
    },
    setScrollParams() {
      this.heightBeforeLoad = this.conversationPanel.scrollHeight;
      this.scrollTopBeforeLoad = this.conversationPanel.scrollTop;
    },

    async fetchPreviousMessages(scrollTop = 0) {
      this.setScrollParams();
      const shouldLoadMoreMessages =
        this.currentChat.dataFetched === true &&
        !this.listLoadingStatus &&
        !this.isLoadingPrevious;

      if (
        scrollTop < 100 &&
        !this.isLoadingPrevious &&
        shouldLoadMoreMessages
      ) {
        this.isLoadingPrevious = true;
        try {
          await this.$store.dispatch('fetchPreviousMessages', {
            conversationId: this.currentChat.id,
            before: this.currentChat.messages[0].id,
          });
          const heightDifference =
            this.conversationPanel.scrollHeight - this.heightBeforeLoad;
          this.conversationPanel.scrollTop =
            this.scrollTopBeforeLoad + heightDifference;
          this.setScrollParams();
        } catch (error) {
          // Ignore Error
        } finally {
          this.isLoadingPrevious = false;
        }
      }
    },

    handleScroll(e) {
      if (this.isProgrammaticScroll) {
        // Reset the flag
        this.isProgrammaticScroll = false;
        this.hasUserScrolled = false;
      } else {
        this.hasUserScrolled = true;
      }
      emitter.emit(BUS_EVENTS.ON_MESSAGE_LIST_SCROLL);
      this.fetchPreviousMessages(e.target.scrollTop);
    },

    makeMessagesRead() {
      this.$store.dispatch('markMessagesRead', { id: this.currentChat.id });
    },
    getInReplyToMessage(parentMessage) {
      if (!parentMessage) return {};
      const inReplyToMessageId = parentMessage.content_attributes?.in_reply_to;
      if (!inReplyToMessageId) return {};

      return this.currentChat?.messages.find(message => {
        if (message.id === inReplyToMessageId) {
          return true;
        }
        return false;
      });
    },
    openStarredMessages() {
      this.showStarredMessagesModal = true;
    },
    closeStarredMessages() {
      this.showStarredMessagesModal = false;
    },
    onScrollToPinnedMessage(messageId) {
      this.onScrollToMessage({ messageId });
    },
    // Message selection methods
    toggleMessageSelection(messageId) {
      const index = this.selectedMessages.indexOf(messageId);
      if (index > -1) {
        this.selectedMessages.splice(index, 1);
      } else {
        this.selectedMessages.push(messageId);
      }
    },
    clearMessageSelection() {
      this.selectedMessages = [];
      this.$emit('toggle-selection-mode'); // This will turn off selection mode
    },
    onTicketCreated(ticket) {
      // Refresh conversation tickets
      this.$store.dispatch('tickets/fetchTicketsForConversation', this.currentChat.id);
      // Clear selection and exit selection mode
      this.clearMessageSelection();
    },
    onMessagesLinked(ticket) {
      // Refresh conversation tickets  
      this.$store.dispatch('tickets/fetchTicketsForConversation', this.currentChat.id);
      // Clear selection and exit selection mode
      this.clearMessageSelection();
    },
    // Build description from selected messages for JIRA issue
    selectedMessagesDescription() {
      const messages = this.currentChat?.messages || [];
      return this.selectedMessages
        .map(id => messages.find(m => m.id === id))
        .filter(Boolean)
        .map(msg => {
          const attrs = msg.content_attributes || {};
          const role = attrs.wa_sender_role || attrs.waSenderRole;
          const sender = role || (msg.message_type === 0 ? 'Customer' : 'Agent');
          const name = attrs.wa_team_member_name || attrs.waTeamMemberName || msg.sender?.name || attrs.wa_sender_name || 'Unknown';
          return `${name} (${sender}): ${msg.content || ''}`;
        })
        .join('\n\n');
    },
    // Modal handlers
    openCreateTicketModal() {
      this.showCreateTicketModal = true;
    },
    openLinkToExistingModal() {
      this.showLinkToExistingModal = true;
    },
    closeCreateTicketModal() {
      this.showCreateTicketModal = false;
    },
    closeLinkToExistingModal() {
      this.showLinkToExistingModal = false;
    },
    onTicketCreatedFromModal() {
      this.closeCreateTicketModal();
      this.clearMessageSelection();
    },
    onMessagesLinkedFromModal(ticket) {
      this.closeLinkToExistingModal();
      this.onMessagesLinked(ticket);
    },
  },
};
</script>

<template>
  <div class="flex flex-col justify-between flex-grow h-full min-w-0 m-0">
    <Banner
      v-if="!currentChat.can_reply"
      color-scheme="alert"
      class="mx-2 mt-2 overflow-hidden rounded-lg"
      :banner-message="replyWindowBannerMessage"
      :href-link="replyWindowLink"
      :href-link-text="replyWindowLinkText"
    />
    <Banner
      v-else-if="hasDuplicateInstagramInbox"
      color-scheme="alert"
      class="mx-2 mt-2 overflow-hidden rounded-lg"
      :banner-message="$t('CONVERSATION.OLD_INSTAGRAM_INBOX_REPLY_BANNER')"
    />
    <PinnedMessagesBar @scroll-to-message="onScrollToPinnedMessage" />
    
    <NextMessageList
      v-if="showNextBubbles"
      ref="conversationPanelRef"
      class="conversation-panel"
      :current-user-id="currentUserId"
      :first-unread-id="unReadMessages[0]?.id"
      :is-an-email-channel="isAnEmailChannel"
      :inbox-supports-reply-to="inboxSupportsReplyTo"
      :messages="getMessages"
      :is-selection-mode="isSelectionMode"
      :selected-messages="selectedMessages"
      @toggle-selection="toggleMessageSelection"
    >
      <template #beforeAll>
        <transition name="slide-up">
          <!-- eslint-disable-next-line vue/require-toggle-inside-transition -->
          <li class="min-h-[4rem]">
            <span v-if="shouldShowSpinner" class="spinner message" />
          </li>
        </transition>
      </template>
      <template #unreadBadge>
        <li v-show="unreadMessageCount != 0" class="unread--toast">
          <span>
            {{ unreadMessageLabel }}
          </span>
        </li>
      </template>
      <template #after>
        <ConversationLabelSuggestion
          v-if="shouldShowLabelSuggestions"
          :suggested-labels="labelSuggestions"
          :chat-labels="currentChat.labels"
          :conversation-id="currentChat.id"
        />
      </template>
    </NextMessageList>
    <ul v-else ref="conversationPanelRef" class="conversation-panel">
      <transition name="slide-up">
        <!-- eslint-disable-next-line vue/require-toggle-inside-transition -->
        <li class="min-h-[4rem]">
          <span v-if="shouldShowSpinner" class="spinner message" />
        </li>
      </transition>
      <Message
        v-for="message in readMessages"
        :key="message.id"
        class="message--read ph-no-capture"
        data-clarity-mask="True"
        :data="message"
        :is-a-tweet="isATweet"
        :is-a-whatsapp-channel="isAWhatsAppChannel"
        :is-web-widget-inbox="isAWebWidgetInbox"
        :is-a-facebook-inbox="isAFacebookInbox"
        :is-an-email-inbox="isAnEmailChannel"
        :is-instagram="isInstagramDM"
        :inbox-supports-reply-to="inboxSupportsReplyTo"
        :in-reply-to="getInReplyToMessage(message)"
      />
      <li v-show="unreadMessageCount != 0" class="unread--toast">
        <span>
          {{ unreadMessageCount > 9 ? '9+' : unreadMessageCount }}
          {{
            unreadMessageCount > 1
              ? $t('CONVERSATION.UNREAD_MESSAGES')
              : $t('CONVERSATION.UNREAD_MESSAGE')
          }}
        </span>
      </li>
      <Message
        v-for="message in unReadMessages"
        :key="message.id"
        class="message--unread ph-no-capture"
        data-clarity-mask="True"
        :data="message"
        :is-a-tweet="isATweet"
        :is-a-whatsapp-channel="isAWhatsAppChannel"
        :is-web-widget-inbox="isAWebWidgetInbox"
        :is-a-facebook-inbox="isAFacebookInbox"
        :is-instagram-dm="isInstagramDM"
        :inbox-supports-reply-to="inboxSupportsReplyTo"
        :in-reply-to="getInReplyToMessage(message)"
      />
      <ConversationLabelSuggestion
        v-if="shouldShowLabelSuggestions"
        :suggested-labels="labelSuggestions"
        :chat-labels="currentChat.labels"
        :conversation-id="currentChat.id"
      />
    </ul>
    <div
      class="conversation-footer"
      :class="{
        'modal-mask': isPopOutReplyBox,
        'bg-n-background': showNextBubbles && !isPopOutReplyBox,
      }"
    >
      <div
        v-if="isAnyoneTyping"
        class="absolute flex items-center w-full h-0 -top-7"
      >
        <div
          class="flex py-2 pr-4 pl-5 shadow-md rounded-full bg-white dark:bg-slate-700 text-n-slate-11 text-xs font-semibold my-2.5 mx-auto"
        >
          {{ typingUserNames }}
          <img
            class="w-6 ltr:ml-2 rtl:mr-2"
            src="assets/images/typing.gif"
            alt="Someone is typing"
          />
        </div>
      </div>
      <ReplyBox
        v-model:popout-reply-box="isPopOutReplyBox"
        @toggle-popout="showPopOutReplyBox"
        @scroll-to-message="onScrollToPinnedMessage"
        @open-starred-messages="openStarredMessages"
      />
    </div>
    
    <!-- Starred Messages Modal -->
    <StarredMessagesModal
      v-if="currentChat && currentChat.id"
      :show="showStarredMessagesModal"
      :conversation-id="currentChat.id"
      @close="closeStarredMessages"
      @scroll-to-message="onScrollToPinnedMessage"
    />
    
    <!-- Message Selection Toolbar -->
    <MessageSelectionToolbar
      v-if="selectedMessages.length > 0"
      :conversation-id="currentChat.id"
      :selected-messages="selectedMessages"
      @clear-selection="clearMessageSelection"
      @create-ticket="openCreateTicketModal"
      @link-to-existing="openLinkToExistingModal"
    />
    
    <!-- Create/Link JIRA Issue Modal -->
    <CreateOrLinkIssue
      v-if="showCreateTicketModal"
      :conversation-id="currentChat.id"
      :title="`Conversation #${currentChat.id}`"
      :description="selectedMessagesDescription()"
      :selected-message-ids="selectedMessages"
      @close="closeCreateTicketModal"
      @issue-created="onTicketCreatedFromModal"
      @issue-linked="onTicketCreatedFromModal"
    />
  
  </div>
</template>

<style scoped lang="scss">
.modal-mask {
  @apply absolute;

  &::v-deep {
    .ProseMirror-woot-style {
      @apply max-h-[25rem];
    }

    .reply-box {
      @apply border border-n-weak max-w-[75rem] w-[70%];

      &.is-private {
        @apply dark:border-n-amber-3/30 border-n-amber-12/5;
      }
    }

    .reply-box .reply-box__top {
      @apply relative min-h-[27.5rem];
    }

    .reply-box__top .input {
      @apply min-h-[27.5rem];
    }

    .emoji-dialog {
      @apply absolute left-auto bottom-1;
    }
  }
}

.starred-messages-button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  margin: 0.5rem 1rem;
  background-color: #f3f4f6;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  cursor: pointer;
  font-size: 0.875rem;
  color: #374151;
  transition: background-color 0.2s;
}

.starred-messages-button:hover {
  background-color: #e5e7eb;
}

.dark .starred-messages-button {
  background-color: #374151;
  border-color: #4b5563;
  color: #f3f4f6;
}

.dark .starred-messages-button:hover {
  background-color: #4b5563;
}

.message--highlighted {
  background-color: rgba(59, 130, 246, 0.1);
  border: 2px solid rgba(59, 130, 246, 0.3);
  border-radius: 8px;
  transition: all 0.3s ease-in-out;
}

.dark .message--highlighted {
  background-color: rgba(59, 130, 246, 0.15);
  border-color: rgba(59, 130, 246, 0.4);
}
</style>
