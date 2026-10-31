# frozen_string_literal: true

class AiAttendant::ReplyBlocks
  class << self
    def parse(text, config)
      files = attached_files(config)

      text.to_s.split("\n\n").flat_map do |chunk|
        expand_chunk(chunk, files)
      end
    end

    def as_json(text, config)
      parse(text, config).map { |block| serialize(block).deep_stringify_keys }
    end

    private

    def attached_files(config)
      return [] if config.blank? || !config.respond_to?(:reference_files)
      return [] unless config.reference_files.attached?

      config.reference_files.to_a
    end

    def expand_chunk(chunk, files)
      lines = chunk.to_s.split("\n")
      return blocks_for(chunk.to_s.strip, files) if lines.size <= 1

      blocks = []
      buffer = []
      flush = lambda do
        joined = buffer.join("\n").strip
        blocks.concat(blocks_for(joined, files)) if joined.present?
        buffer = []
      end

      lines.each do |line|
        if AiAttendant::ReferenceVariables.contains_token?(line)
          flush.call
          blocks.concat(blocks_for(line.strip, files))
          next
        end

        file = matching_file(files, line)
        if file
          flush.call
          blocks << attachment_block(file, line)
        else
          buffer << line
        end
      end
      flush.call
      blocks
    end

    def blocks_for(content, files)
      return [] if content.blank?

      file = matching_file(files, content)
      return [attachment_block(file, content)] if file

      segments = AiAttendant::ReferenceVariables.split_message(content, files)
      if segments.present?
        return segments.flat_map do |segment|
          case segment[:type]
          when :attachment
            [attachment_block(segment[:file], segment[:token])]
          when :text
            segment[:content].present? ? [{ type: :text, content: segment[:content] }] : []
          end
        end
      end

      [{ type: :text, content: content }]
    end

    def matching_file(files, content)
      stripped = content.to_s.strip
      matched = AiAttendant::ReferenceVariables.lookup_file(files, stripped)
      return matched if matched

      files.find { |file| blob_url_match?(stripped, file) }
    end

    def blob_url_match?(stripped, file)
      blob_urls_for(file).any? { |url| stripped == url || url.ends_with?(stripped) || stripped.ends_with?(url) }
    end

    def blob_urls_for(file)
      [
        blob_url_for(file),
        ActiveStorageUrlHelper.url_for_attachment(file, only_path: false)
      ].uniq
    end

    def attachment_block(file, content)
      entry = AiAttendant::ReferenceVariables.entries([file]).first
      {
        type: :attachment,
        content: '',
        token: entry[:token],
        file: file,
        filename: entry[:filename],
        content_type: file.content_type,
        file_type: file_type_for(file),
        url: blob_url_for(file)
      }
    end

    def serialize(block)
      if block[:type] == :attachment
        {
          type: 'attachment',
          content: '',
          token: block[:token],
          filename: block[:filename],
          content_type: block[:content_type],
          file_type: block[:file_type],
          url: block[:url]
        }
      else
        { type: 'text', content: block[:content] }
      end
    end

    def file_type_for(file)
      type = file.content_type.to_s
      return 'image' if type.start_with?('image/')
      return 'video' if type.start_with?('video/')
      return 'audio' if type.start_with?('audio/')

      'file'
    end

    def blob_url_for(file)
      ActiveStorageUrlHelper.url_for_attachment(file, only_path: true)
    end
  end
end
