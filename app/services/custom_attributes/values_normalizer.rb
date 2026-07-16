# frozen_string_literal: true

module CustomAttributes
  class ValuesNormalizer
    def self.labels(values)
      new(values).labels
    end

    def self.for_api(values)
      new(values).for_api
    end

    def initialize(values)
      @values = values
    end

    def labels
      for_api.filter_map { |item| extract_label(item) }
    end

    def for_api
      normalize_for_api(@values)
    end

    private

    def normalize_for_api(values)
      return [] if values.blank?

      if values.is_a?(Hash)
        stages = values['stages'] || values[:stages] || values['values'] || values[:values]
        if stages.is_a?(Array)
          return stages
        elsif stages.is_a?(Hash)
          return ordered_stages_from_hash(stages, values)
        end

        return []
      end

      return values if values.is_a?(Array)

      []
    end

    def ordered_stages_from_hash(stages, values)
      stage_order = values['stage_order'] || values[:stage_order]

      if stage_order.is_a?(Array) && stage_order.any?
        ordered_names = stage_order.map(&:to_s).select { |name| stages.key?(name) }
        remaining_names = stages.keys.map(&:to_s) - ordered_names
        names = ordered_names + remaining_names
      else
        names = stages.keys.map(&:to_s)
      end

      names.filter_map do |name|
        data = stages[name] || stages[name.to_sym]
        next unless data

        { name: name.to_s, color: data['color'] || data[:color] }
      end
    end

    def extract_label(item)
      case item
      when String
        item.presence
      when Hash
        (item['name'] || item[:name] || item['label'] || item[:label] || item['value'] || item[:value]).presence&.to_s
      else
        item.to_s.presence
      end
    end
  end
end
