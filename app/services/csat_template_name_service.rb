class CsatTemplateNameService
  CSAT_BASE_NAME = 'customer_satisfaction_survey'.freeze

  def self.csat_template_name(inbox_id, version = nil)
    base_name = csat_base_name_for_inbox(inbox_id)
    version ? "#{base_name}_#{version}" : base_name
  end

  def self.extract_version(template_name, inbox_id)
    return nil if template_name.blank?

    match = template_name.match(versioned_pattern_for_inbox(inbox_id))
    match ? match[1].to_i : nil
  end

  def self.generate_next_template_name(_base_name, inbox_id, current_template_name)
    return csat_template_name(inbox_id) if current_template_name.blank?

    current_version = extract_version(current_template_name, inbox_id)
    next_version = current_version ? current_version + 1 : 1
    csat_template_name(inbox_id, next_version)
  end

  def self.csat_base_name_for_inbox(inbox_id)
    "#{CSAT_BASE_NAME}_#{inbox_id}"
  end

  def self.versioned_pattern_for_inbox(inbox_id)
    /^#{CSAT_BASE_NAME}_#{inbox_id}_(\d+)$/
  end

  private_class_method :csat_base_name_for_inbox, :versioned_pattern_for_inbox
end
