class ChatwootMarkdownRenderer
  def initialize(content)
    @content = content
  end

  def render_message
    markdown_renderer = BaseMarkdownRenderer.new
    doc = CommonMarker.render_doc(@content, :DEFAULT)
    html = markdown_renderer.render(doc)
    render_as_html_safe(html)
  end

  def render_article
    markdown_renderer = CustomMarkdownRenderer.new
    processed_content = preprocess_tables(@content)
    doc = CommonMarker.render_doc(processed_content, :DEFAULT, [:table])
    html = markdown_renderer.render(doc)

    render_as_html_safe(html)
  end

  def render_markdown_to_plain_text
    CommonMarker.render_doc(@content, :DEFAULT).to_plaintext
  end

  private

  # Removes blank lines between table rows to ensure proper table parsing
  # ProseMirror sometimes inserts blank lines between table rows which breaks markdown table syntax
  def preprocess_tables(content)
    return '' if content.blank?

    lines = content.split("\n")
    result = []
    table_buffer = []
    blank_line_buffer = []

    lines.each do |line|
      trimmed_line = line.strip
      is_table_row = trimmed_line.match?(/^\|.+\|$/)
      is_separator_row = trimmed_line.match?(/^\|[\s\-:|]+\|$/)
      is_empty_line = trimmed_line.empty?

      if is_table_row || is_separator_row
        # We're in a table, discard any buffered blank lines within the table
        blank_line_buffer = []
        table_buffer << trimmed_line
      elsif is_empty_line && table_buffer.any?
        # Buffer blank lines while we're in a table context
        blank_line_buffer << line
      else
        # Non-table content - flush the table buffer if we have one
        if table_buffer.any?
          result << table_buffer.join("\n")
          table_buffer = []
        end
        # Add any blank lines that were between table and this content
        result.concat(blank_line_buffer)
        blank_line_buffer = []
        result << line
      end
    end

    # Flush any remaining table content
    result << table_buffer.join("\n") if table_buffer.any?
    result.concat(blank_line_buffer)

    result.join("\n")
  end

  def render_as_html_safe(html)
    # rubocop:disable Rails/OutputSafety
    html.html_safe
    # rubocop:enable Rails/OutputSafety
  end
end
