# frozen_string_literal: true

class AiAttendant::ReferenceVariables
  TOKEN_PREFIX = 'anexo'
  LEGACY_TOKEN = '[REFERENCIA]'
  TOKEN_CAPTURE = /\{\{anexo:([a-z0-9_.-]+)\}\}/i
  TOKEN_PATTERN = /\A#{TOKEN_CAPTURE.source}\z/i

  class << self
    def entries(files)
      used = []
      Array(files).map do |file|
        key = unique_key(base_name(file), used)
        used << key
        {
          key: key,
          token: token_for(key),
          filename: filename_for(file),
          file: file
        }
      end
    end

    def token_for(key)
      "{{#{TOKEN_PREFIX}:#{key}}}"
    end

    def lookup_file(files, content)
      key = extract_key(content)
      return if key.blank?

      lookup_file_by_key(files, key)
    end

    def lookup_file_by_key(files, key)
      normalized = normalize_key(key)
      entry = entries(files).find { |entry| normalize_key(entry[:key]) == normalized }
      return entry[:file] if entry

      stripped = key.to_s.sub(/\.[^.]+\z/i, '')
      return if stripped == key.to_s

      normalized_stripped = normalize_key(stripped)
      entries(files).find { |entry| normalize_key(entry[:key]) == normalized_stripped }&.fetch(:file)
    end

    def contains_token?(content)
      unwrap(content).match?(TOKEN_CAPTURE)
    end

    def split_message(content, files)
      stripped = unwrap(content)
      return [] unless stripped.match?(TOKEN_CAPTURE)

      keys = stripped.scan(TOKEN_CAPTURE).flatten
      return [] if keys.any? { |key| lookup_file_by_key(files, key).blank? }

      segments = []
      cursor = 0
      while (match = stripped.match(TOKEN_CAPTURE, cursor))
        before = stripped[cursor...match.begin(0)].strip
        segments << { type: :text, content: before } if before.present?

        token = match[0]
        file = lookup_file_by_key(files, match[1])
        if file
          segments << { type: :attachment, file: file, token: token }
        else
          segments << { type: :text, content: token }
        end
        cursor = match.end(0)
      end

      tail = stripped[cursor..].strip
      segments << { type: :text, content: tail } if tail.present?
      segments
    end

    def inline_attachment(files, content)
      segments = split_message(content, files)
      return if segments.size != 2
      return unless segments[0][:type] == :text && segments[1][:type] == :attachment

      {
        text: segments[0][:content],
        token: segments[1][:token],
        file: segments[1][:file]
      }
    end

    def extract_key(content)
      stripped = unwrap(content)
      exact = stripped.match(TOKEN_PATTERN)
      return exact[1] if exact

      tokens = stripped.scan(TOKEN_CAPTURE)
      return if tokens.size != 1
      return unless stripped.gsub(TOKEN_CAPTURE, '').strip.blank?

      tokens.first.first
    end

    def replace_legacy_tokens(text, files)
      list = entries(files)
      return text.to_s if list.empty?

      index = -1
      text.to_s.gsub(LEGACY_TOKEN) do
        index += 1
        list.dig(index, :token) || list.last[:token]
      end
    end

    private

    def filename_for(file)
      return file.filename.to_s if file.respond_to?(:filename)

      file.to_s
    end

    def base_name(file)
      File.basename(filename_for(file), '.*')
    end

    def unique_key(name, used)
      key = slug(name)
      return key unless used.include?(key)

      index = 2
      index += 1 while used.include?("#{key}-#{index}")
      "#{key}-#{index}"
    end

    def slug(name)
      parameterized = name.to_s.parameterize
      parameterized.presence || 'arquivo'
    end

    def unwrap(content)
      content.to_s.strip.gsub(/\A[`"'“”]+|[`"'“”]+\z/, '')
    end

    def normalize_key(key)
      key.to_s.downcase.tr('_', '-')
    end
  end
end
