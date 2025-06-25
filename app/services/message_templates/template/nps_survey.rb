class MessageTemplates::Template::NpsSurvey
  pattr_initialize [:conversation!]

  def perform
    return unless should_send_nps_survey?

    ActiveRecord::Base.transaction do
      conversation.messages.create!(nps_survey_message_params)
    end
  end

  private

  delegate :contact, :account, :inbox, to: :conversation

  def should_send_nps_survey?
    return true unless survey_rules_configured?

    labels = conversation.label_list

    return true if rule_values.empty?

    case rule_operator
    when 'contains'
      rule_values.any? { |label| labels.include?(label) }
    when 'does_not_contain'
      rule_values.none? { |label| labels.include?(label) }
    else
      true
    end
  end

  def survey_rules_configured?
    return false if nps_config.blank?
    return false if nps_config['survey_rules'].blank?
    return false if rule_values.empty?

    true
  end

  def rule_operator
    nps_config.dig('survey_rules', 'operator') || 'contains'
  end

  def rule_values
    nps_config.dig('survey_rules', 'values') || []
  end

  def message_content
    return I18n.t('conversations.templates.nps_input_message_body') if nps_config.blank? || nps_config['message'].blank?

    nps_config['message']
  end

  def nps_survey_message_params
    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content_type: :input_nps,
      content: message_content,
      content_attributes: content_attributes
    }
  end

  def nps_config
    # For now, we'll use a default NPS config since there's no inbox-specific NPS config yet
    # This can be expanded to use inbox.nps_config in the future
    @nps_config ||= {
      'message' => I18n.t('conversations.templates.nps_input_message_body'),
      'display_type' => 'scale'
    }
  end

  def content_attributes
    {
      display_type: nps_config['display_type'] || 'scale'
    }
  end
end
