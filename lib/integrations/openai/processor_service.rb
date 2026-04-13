class Integrations::Openai::ProcessorService < Integrations::OpenaiBaseService
  AGENT_INSTRUCTION = 'You are a helpful support agent.'.freeze
  LANGUAGE_INSTRUCTION = 'Ensure that the reply should be in user language.'.freeze
  def reply_suggestion_message
    make_api_call(reply_suggestion_body)
  end

  def summarize_message
    make_api_call(summarize_body)
  end

  def rephrase_message
    make_api_call(build_api_call_body("#{AGENT_INSTRUCTION} Please rephrase the following response. " \
                                      "#{LANGUAGE_INSTRUCTION}"))
  end

  def fix_spelling_grammar_message
    make_api_call(build_api_call_body("#{AGENT_INSTRUCTION} Please fix the spelling and grammar of the following response. " \
                                      "#{LANGUAGE_INSTRUCTION}"))
  end

  def shorten_message
    make_api_call(build_api_call_body("#{AGENT_INSTRUCTION} Please shorten the following response. " \
                                      "#{LANGUAGE_INSTRUCTION}"))
  end

  def expand_message
    make_api_call(build_api_call_body("#{AGENT_INSTRUCTION} Please expand the following response. " \
                                      "#{LANGUAGE_INSTRUCTION}"))
  end

  def make_friendly_message
    make_api_call(build_api_call_body("#{AGENT_INSTRUCTION} Please make the following response more friendly. " \
                                      "#{LANGUAGE_INSTRUCTION}"))
  end

  def make_formal_message
    make_api_call(build_api_call_body("#{AGENT_INSTRUCTION} Please make the following response more formal. " \
                                      "#{LANGUAGE_INSTRUCTION}"))
  end

  def simplify_message
    make_api_call(build_api_call_body("#{AGENT_INSTRUCTION} Please simplify the following response. " \
                                      "#{LANGUAGE_INSTRUCTION}"))
  end

  def enhance_ticket_message
    Rails.logger.info 'Processing AI enhancement for support ticket'
    
    # Handle ActionController::Parameters properly
    ticket_data = if event['data'].is_a?(ActionController::Parameters)
                    event['data'].permit!.to_h
                  else
                    event['data']
                  end
    
    enhancement_options = ticket_data['enhancement_options'] || []
    available_categories = ticket_data['available_categories'] || []
    
    Rails.logger.info "Enhancement options: #{enhancement_options.inspect}"
    Rails.logger.info "Available categories: #{available_categories.inspect}"
    
    # Build system instructions based on selected options
    system_instructions = build_enhancement_instructions(enhancement_options, ticket_data)
    Rails.logger.info "System instructions: #{system_instructions}"
    
    # Build user content with linked messages as primary source
    user_content = build_user_content_for_enhancement(ticket_data)
    Rails.logger.info "User content: #{user_content}"
    
    Rails.logger.info 'Making API call to OpenAI'
    result = make_api_call(build_api_call_body(system_instructions, user_content))
    Rails.logger.info "OpenAI API result: #{result.inspect}"
    
    result
  end

  def build_enhancement_instructions(enhancement_options, ticket_data = {})
    base_instruction = "#{AGENT_INSTRUCTION} You are helping to create support tickets based on conversation messages. Your primary goal is accuracy and staying strictly focused on what the customer actually reported. Do NOT infer additional problems, add generic advice, or make assumptions beyond what is explicitly stated in the conversation."

    instructions = []

    if enhancement_options.include?('improve_title')
      instructions << '- Create a clear, specific, and actionable title that directly reflects the core issue mentioned by the customer. Use technical terms if mentioned. Avoid generic phrases. Keep it under 80 characters. Focus on the ACTUAL problem described, not potential solutions.'
    end

    if enhancement_options.include?('improve_description')
      instructions << "- Write a focused description that:
        • Summarizes the specific problem the customer described
        • Includes relevant details, error messages, or technical information mentioned
        • Maintains the customer's context and terminology
        • Does NOT add assumptions, generic troubleshooting steps, or solutions not requested
        • Stays strictly within the scope of what was actually reported
        • Uses clear, professional language while preserving important user details"
    end

    if enhancement_options.include?('suggest_priority')
      instructions << build_priority_mapping_instructions
    end

    if enhancement_options.include?('suggest_issue_type')
      available_issue_types = ticket_data['available_issue_types'] || %w[Bug Task Story Epic]
      types_list = available_issue_types.join(', ')
      instructions << "- Suggest the most appropriate JIRA issue type from these options: #{types_list}. Choose 'Bug' for defects/errors, 'Task' for general work items, 'Story' for feature-related requests."
    end

    if enhancement_options.include?('suggest_category')
      available_categories = ticket_data['available_categories'] || []
      if available_categories.any?
        categories_list = available_categories.join(', ')
        instructions << "- Suggest the most appropriate category from these available options: #{categories_list}"
      else
        instructions << '- Suggest an appropriate category for this ticket'
      end
    end

    if enhancement_options.include?('suggest_labels')
      instructions << '- Suggest relevant labels/tags that categorize this issue (max 5)'
    end

    if enhancement_options.include?('action_recommendations')
      instructions << '- Provide actionable next steps or recommendations for resolving this issue'
    end

    instructions_text = instructions.join("\n")

    response_format = build_response_format_instructions(enhancement_options)

    "#{base_instruction}\n\nAnalyze the conversation messages and:\n#{instructions_text}\n\n#{response_format}"
  end

  def build_priority_mapping_instructions
    priority_mapping = {
      'urgent' => ['Payroll', 'Billing', 'General'],
      'high' => ['Attendance Tracking', 'Support Chat', 'Mobile Attendance'], 
      'medium' => ['Onboarding', 'Requests', 'View Employee', 'Leave Balance', 'Attendance Schedule', 'Reports', 'Mobile App', 'Setup Role'],
      'low' => ['Home', 'Dashboard', 'Applicant', 'Setup Organization', 'Setup Employment Settings', 'Setup Leave Management', 'Setup Request Config', 'Setup Attendance Rule', 'Setup Payroll Management', 'Setup Laws']
    }

    mapping_text = priority_mapping.map do |priority, categories|
      "#{priority}: #{categories.join(', ')}"
    end.join("\n")

    "- Determine the priority level based on the following category-to-priority mapping. Analyze the conversation to identify which category the issue relates to, then assign the corresponding priority:\n\n#{mapping_text}\n\nIf the issue doesn't clearly fit any specific category, use 'medium' as the default priority. Focus on the actual impact described by the user rather than making assumptions."
  end

  def build_response_format_instructions(enhancement_options)
    format_fields = []

    format_fields << '"title": "enhanced title text"' if enhancement_options.include?('improve_title')

    format_fields << '"description": "enhanced description text"' if enhancement_options.include?('improve_description')

    format_fields << '"priority": "urgent|high|medium|low"' if enhancement_options.include?('suggest_priority')

    format_fields << '"issue_type": "suggested issue type"' if enhancement_options.include?('suggest_issue_type')

    format_fields << '"category": "suggested category"' if enhancement_options.include?('suggest_category')

    format_fields << '"labels": ["label1", "label2", ...]' if enhancement_options.include?('suggest_labels')

    if enhancement_options.include?('action_recommendations')
      format_fields << '"recommendations": ["action1", "action2", ...]'
    end

    format_text = format_fields.join(', ')

    "Return ONLY a valid JSON response with the following structure: { #{format_text} }. " \
    'Do not include any markdown formatting, explanations, or additional text outside the JSON.'
  end

  def build_user_content_for_enhancement(ticket_data)
    content_parts = []

    # Add linked messages as primary source of information
    if ticket_data['messages'].present?
      content_parts << '=== CONVERSATION MESSAGES ==='
      content_parts << ticket_data['messages'].strip
      content_parts << ''
    end

    # Fallback if no messages provided
    if content_parts.empty?
      content_parts << 'No conversation messages provided. Please create a generic support ticket structure.'
    end

    content_parts.join("\n")
  end

  private

  def prompt_from_file(file_name, enterprise: false)
    path = enterprise ? 'enterprise/lib/enterprise/integrations/openai_prompts' : 'lib/integrations/openai/openai_prompts'
    Rails.root.join(path, "#{file_name}.txt").read
  end

  def build_api_call_body(system_content, user_content = event['data']['content'])
    {
      model: GPT_MODEL,
      messages: [
        { role: 'system', content: system_content },
        { role: 'user', content: user_content }
      ]
    }.to_json
  end

  def conversation_messages(in_array_format: false)
    messages = init_messages_body(in_array_format)

    add_messages_until_token_limit(conversation, messages, in_array_format)
  end

  def add_messages_until_token_limit(conversation, messages, in_array_format, start_from = 0)
    character_count = start_from
    conversation.messages.where(message_type: %i[incoming
                                                 outgoing]).where(private: false).reorder('id desc').each do |message|
      character_count, message_added = add_message_if_within_limit(character_count, message, messages, in_array_format)
      break unless message_added
    end
    messages
  end

  def add_message_if_within_limit(character_count, message, messages, in_array_format)
    if valid_message?(message, character_count)
      add_message_to_list(message, messages, in_array_format)
      character_count += message.content.length
      [character_count, true]
    else
      [character_count, false]
    end
  end

  def valid_message?(message, character_count)
    message.content.present? && character_count + message.content.length <= TOKEN_LIMIT
  end

  def add_message_to_list(message, messages, in_array_format)
    formatted_message = format_message(message, in_array_format)
    messages.prepend(formatted_message)
  end

  def init_messages_body(in_array_format)
    in_array_format ? [] : ''
  end

  def format_message(message, in_array_format)
    in_array_format ? format_message_in_array(message) : format_message_in_string(message)
  end

  def format_message_in_array(message)
    { role: (message.incoming? ? 'user' : 'assistant'), content: message.content }
  end

  def format_message_in_string(message)
    sender_type = message.incoming? ? 'Customer' : 'Agent'
    "#{sender_type} #{message.sender&.name} : #{message.content}\n"
  end

  def summarize_body
    {
      model: GPT_MODEL,
      messages: [
        { role: 'system',
          content: prompt_from_file('summary', enterprise: false) },
        { role: 'user', content: conversation_messages }
      ]
    }.to_json
  end

  def reply_suggestion_body
    {
      model: GPT_MODEL,
      messages: [
        { role: 'system',
          content: prompt_from_file('reply', enterprise: false) }
      ].concat(conversation_messages(in_array_format: true))
    }.to_json
  end
end

Integrations::Openai::ProcessorService.prepend_mod_with('Integrations::OpenaiProcessorService')
