<script>
import { mapActions, mapGetters } from 'vuex';
import { getContrastingTextColor } from '@chatwoot/utils';
import CustomButton from 'shared/components/Button.vue';
import FooterReplyTo from 'widget/components/FooterReplyTo.vue';
import ChatInputWrap from 'widget/components/ChatInputWrap.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { sendEmailTranscript } from 'widget/api/conversation';
import routerMixin from 'widget/mixins/routerMixin';
import configMixin from 'widget/mixins/configMixin';
import { IFrameHelper } from '../helpers/utils';
import { CHATWOOT_ON_START_CONVERSATION } from '../constants/sdkEvents';
import { emitter } from 'shared/helpers/mitt';

export default {
  components: {
    ChatInputWrap,
    CustomButton,
    FooterReplyTo,
  },
  mixins: [routerMixin, configMixin],
  data() {
    return {
      inReplyTo: null,
    };
  },
  computed: {
    ...mapGetters({
      conversationAttributes: 'conversationAttributes/getConversationParams',
      widgetColor: 'appConfig/getWidgetColor',
      conversationSize: 'conversation/getConversationSize',
      currentUser: 'contacts/getCurrentUser',
      isWidgetStyleFlat: 'appConfig/isWidgetStyleFlat',
      allMessages: 'conversation/getConversation',
    }),
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    hideReplyBox() {
      const { allowMessagesAfterResolved } = window.chatwootWebChannel;
      const { status } = this.conversationAttributes;
      return !allowMessagesAfterResolved && status === 'resolved';
    },
    showEmailTranscriptButton() {
      return this.hasEmail;
    },
    hasEmail() {
      return this.currentUser && this.currentUser.has_email;
    },
    hasReplyTo() {
      return (
        this.inReplyTo && (this.inReplyTo.content || this.inReplyTo.attachments)
      );
    },
    hasPendingSurveyFeedback() {
      if (!this.allMessages || Object.keys(this.allMessages).length === 0) {
        return false;
      }
      
      const messages = Object.values(this.allMessages);
      return messages.some(message => {
        // Check for unanswered CSAT surveys
        if (message.content_type === 'input_csat') {
          const submittedValues = message.content_attributes?.submitted_values;
          const csatResponse = submittedValues?.csat_survey_response;
          
          // If no rating provided at all, survey is pending
          if (!csatResponse?.rating) {
            return true;
          }
          
          // If rating 1-3 provided but no feedback, survey is pending
          if (csatResponse.rating <= 3 && !csatResponse.feedback_message) {
            return true;
          }
        }
        
        // Check for unanswered NPS surveys
        if (message.content_type === 'input_nps') {
          const submittedValues = message.content_attributes?.submitted_values;
          const npsResponse = submittedValues?.nps_survey_response;
          
          // If no rating provided at all, survey is pending
          if (npsResponse?.rating === undefined || npsResponse?.rating === null) {
            return true;
          }
          
          // If rating 0-8 provided but no feedback, survey is pending
          if (npsResponse.rating <= 8 && !npsResponse.feedback_message) {
            return true;
          }
        }
        
        return false;
      });
    },
    isMessageSendingDisabled() {
      return this.hideReplyBox || (this.responseMandatory && this.hasPendingSurveyFeedback);
    },
    disabledMessage() {
      if (this.responseMandatory && this.hasPendingSurveyFeedback) {
        // Check what type of survey is pending
        const messages = Object.values(this.allMessages || {});
        for (const message of messages) {
          if (message.content_type === 'input_csat') {
            const submittedValues = message.content_attributes?.submitted_values;
            const csatResponse = submittedValues?.csat_survey_response;
            
            if (!csatResponse?.rating) {
              return this.$t('CSAT_RATING_REQUIRED') || 'Please provide a rating to continue';
            }
            if (csatResponse.rating <= 3 && !csatResponse.feedback_message) {
              return this.$t('CSAT_FEEDBACK_REQUIRED') || 'Please provide feedback for your rating to continue';
            }
          }
          
          if (message.content_type === 'input_nps') {
            const submittedValues = message.content_attributes?.submitted_values;
            const npsResponse = submittedValues?.nps_survey_response;
            
            if (npsResponse?.rating === undefined || npsResponse?.rating === null) {
              return this.$t('NPS_RATING_REQUIRED') || 'Please provide a rating to continue';
            }
            if (npsResponse.rating <= 8 && !npsResponse.feedback_message) {
              return this.$t('NPS_FEEDBACK_REQUIRED') || 'Please provide feedback for your rating to continue';
            }
          }
        }
        
        return this.$t('SURVEY_FEEDBACK_REQUIRED') || 'Please complete the survey before sending new messages';
      }
      return '';
    },
  },
  mounted() {
    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.toggleReplyTo);
  },
  methods: {
    ...mapActions('conversation', [
      'sendMessage',
      'sendAttachment',
      'clearConversations',
    ]),
    ...mapActions('conversationAttributes', [
      'getAttributes',
      'clearConversationAttributes',
    ]),
    async handleSendMessage(content) {
      // Prevent sending if there's pending survey feedback and response is mandatory
      if (this.responseMandatory && this.hasPendingSurveyFeedback) {
        return;
      }
      
      await this.sendMessage({
        content,
        replyTo: this.inReplyTo ? this.inReplyTo.id : null,
      });
      // reset replyTo message after sending
      this.inReplyTo = null;
      // Update conversation attributes on new conversation
      if (this.conversationSize === 0) {
        this.getAttributes();
      }
    },
    async handleSendAttachment(attachment) {
      // Prevent sending if there's pending survey feedback and response is mandatory
      if (this.responseMandatory && this.hasPendingSurveyFeedback) {
        return;
      }
      
      await this.sendAttachment({
        attachment,
        replyTo: this.inReplyTo ? this.inReplyTo.id : null,
      });
      this.inReplyTo = null;
    },
    startNewConversation() {
      this.clearConversations();
      this.clearConversationAttributes();
      this.replaceRoute('prechat-form');
      IFrameHelper.sendMessage({
        event: 'onEvent',
        eventIdentifier: CHATWOOT_ON_START_CONVERSATION,
        data: { hasConversation: true },
      });
    },
    toggleReplyTo(message) {
      this.inReplyTo = message;
    },
    async sendTranscript() {
      if (this.hasEmail) {
        try {
          await sendEmailTranscript();
          emitter.emit(BUS_EVENTS.SHOW_ALERT, {
            message: this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_SUCCESS'),
            type: 'success',
          });
        } catch (error) {
          emitter.$emit(BUS_EVENTS.SHOW_ALERT, {
            message: this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_ERROR'),
          });
        }
      }
    },
  },
};
</script>

<template>
  <footer
    v-if="!hideReplyBox"
    class="relative z-50 mb-1"
    :class="{
      'rounded-lg': !isWidgetStyleFlat,
      'pt-2.5 shadow-[0px_-20px_20px_1px_rgba(0,_0,_0,_0.05)] dark:shadow-[0px_-20px_20px_1px_rgba(0,_0,_0,_0.15)] rounded-t-none':
        hasReplyTo,
    }"
  >
    <FooterReplyTo
      v-if="hasReplyTo"
      :in-reply-to="inReplyTo"
      @dismiss="inReplyTo = null"
    />
    
    <!-- Show feedback required message when surveys are pending and responses are mandatory -->
    <div v-if="responseMandatory && hasPendingSurveyFeedback" class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-3 mb-2 mx-3">
      <p class="text-red-600 dark:text-red-400 text-sm text-center">
        {{ disabledMessage }}
      </p>
    </div>
    
    <ChatInputWrap
      class="shadow-sm"
      :disabled="responseMandatory && hasPendingSurveyFeedback"
      :disabled-message="disabledMessage"
      :on-send-message="handleSendMessage"
      :on-send-attachment="handleSendAttachment"
    />
  </footer>
  <div v-else>
    <CustomButton
      class="font-medium"
      block
      :bg-color="widgetColor"
      :text-color="textColor"
      @click="startNewConversation"
    >
      {{ $t('START_NEW_CONVERSATION') }}
    </CustomButton>
    <CustomButton
      v-if="showEmailTranscriptButton"
      type="clear"
      class="font-normal"
      @click="sendTranscript"
    >
      {{ $t('EMAIL_TRANSCRIPT.BUTTON_TEXT') }}
    </CustomButton>
  </div>
</template>
