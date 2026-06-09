# frozen_string_literal: true

module Workflows
  class AbVariantSelector
    def initialize(contact_id:, node_id:, variants:)
      @contact_id = contact_id
      @node_id = node_id
      @variants = variants
    end

    def selected_variant
      return nil if @variants.blank?

      total_weight = @variants.sum { |v| v['weight'].to_i.positive? ? v['weight'].to_i : 1 }
      bucket = Zlib.crc32("#{@contact_id}:#{@node_id}") % total_weight
      cumulative = 0

      @variants.each do |variant|
        weight = variant['weight'].to_i.positive? ? variant['weight'].to_i : 1
        cumulative += weight
        return variant if bucket < cumulative
      end

      @variants.first
    end

    def self.suggested_winner(enrollment:, node_id:, min_sample: 50)
      executions = enrollment.workflow_step_executions
                           .where(node_id: node_id, status: 'completed')
                           .where("metadata ->> 'variant_id' IS NOT NULL")

      stats = executions.group("metadata ->> 'variant_id'")
                        .pluck(Arel.sql("metadata ->> 'variant_id'"), Arel.sql('COUNT(*)'),
                               Arel.sql("SUM(CASE WHEN metadata ->> 'replied' = 'true' THEN 1 ELSE 0 END)"))

      return nil if stats.blank?

      stats.each do |_variant_id, count, _replies|
        return nil if count.to_i < min_sample
      end

      stats.max_by do |(_variant_id, count, replies)|
        count.to_i.positive? ? replies.to_f / count.to_i : 0
      end&.first
    end
  end
end
