module RichTextHelper
  def rich_text_editor_options(**overrides)
    {
      attachments: true,
      "permitted-attachment-types": ActiveStorage::UploadLimits::CONTENT_TYPES.join(" ")
    }.merge(overrides)
  end

  # Preserve links instead of making every viewer contact an external GIF host.
  # Uploaded attachments are still rendered by ActionText.
  def embed_gif_links(html)
    html
  end
end
