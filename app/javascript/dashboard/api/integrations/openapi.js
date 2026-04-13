/* global axios */

import ApiClient from '../ApiClient';

/**
 * Represents the data object for a OpenAI hook.
 * @typedef {Object} ConversationMessageData
 * @property {string} [tone] - The tone of the message.
 * @property {string} [content] - The content of the message.
 * @property {string} [conversation_display_id] - The display ID of the conversation (optional).
 */

/**
 * A client for the OpenAI API.
 * @extends ApiClient
 */
class OpenAIAPI extends ApiClient {
  /**
   * Creates a new OpenAIAPI instance.
   */
  constructor() {
    super('integrations', { accountScoped: true });

    /**
     * The conversation events supported by the API.
     * @type {string[]}
     */
    this.conversation_events = [
      'summarize',
      'reply_suggestion',
      'label_suggestion',
    ];

    /**
     * The message events supported by the API.
     * @type {string[]}
     */
    this.message_events = ['rephrase'];

    /**
     * The ticket events supported by the API.
     * @type {string[]}
     */
    this.ticket_events = ['enhance_ticket'];
  }

  /**
   * Processes an event using the OpenAI API.
   * @param {Object} options - The options for the event.
   * @param {string} [options.type='rephrase'] - The type of event to process.
   * @param {string} [options.content] - The content of the event.
   * @param {string} [options.tone] - The tone of the event.
   * @param {string} [options.conversationId] - The ID of the conversation to process the event for.
   * @param {string} options.hookId - The ID of the hook to use for processing the event.
   * @returns {Promise} A promise that resolves with the result of the event processing.
   */
  processEvent({ type = 'rephrase', content, tone, conversationId, hookId }) {
    /**
     * @type {ConversationMessageData}
     */
    let data = {
      tone,
      content,
    };

    if (this.conversation_events.includes(type)) {
      data = {
        conversation_display_id: conversationId,
      };
    }

    return axios.post(`${this.url}/hooks/${hookId}/process_event`, {
      event: {
        name: type,
        data,
      },
    });
  }

  /**
   * Enhances a ticket's title and description using AI.
   * @param {Object} options - The options for ticket enhancement.
   * @param {string} options.title - The current title of the ticket.
   * @param {string} options.description - The current description of the ticket.
   * @param {string} options.messages - The messages content for context.
   * @param {Array} options.enhancementOptions - The enhancement options requested.
   * @param {Array} options.availableCategories - The available categories to choose from.
   * @param {string} options.hookId - The ID of the hook to use for processing the enhancement.
   * @returns {Promise} A promise that resolves with the enhanced ticket data.
   */
  enhanceTicket({ title, description, messages, enhancementOptions, availableCategories, availableIssueTypes, hookId }) {
    return axios.post(`${this.url}/hooks/${hookId}/process_event`, {
      event: {
        name: 'enhance_ticket',
        data: {
          title,
          description,
          messages,
          enhancement_options: enhancementOptions,
          available_categories: availableCategories,
          available_issue_types: availableIssueTypes,
        },
      },
    });
  }
}

export default new OpenAIAPI();
