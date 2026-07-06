# frozen_string_literal: true

class AccountForm < ApplicationRecord
  DEFAULT_DEFINITION = {
    'fields' => [
      { 'key' => 'name', 'type' => 'native', 'field' => 'name', 'label' => 'Nome', 'required' => true },
      { 'key' => 'email', 'type' => 'native', 'field' => 'email', 'label' => 'E-mail', 'required' => true },
      { 'key' => 'phone_number', 'type' => 'native', 'field' => 'phone_number', 'label' => 'Telefone', 'required' => false }
    ]
  }.freeze

  DEFAULT_BRANDING = {
    'primary_color' => '#1f93ff',
    'background_color' => '#ffffff',
    'page_background_color' => '#f8fafc',
    'text_color' => '#0f172a',
    'logo_url' => '',
    'logo_alignment' => 'center',
    'logo_expand' => false,
    'header_title' => '',
    'header_description' => ''
  }.freeze

  DEFAULT_SETTINGS = {
    'confirmation_message' => 'Recebemos seus dados. Em breve entraremos em contato.',
    'dedup_key' => 'email',
    'dedup_policy' => 'update_existing'
  }.freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  has_many :form_submissions, dependent: :delete_all

  enum status: { draft: 0, published: 1, paused: 2 }

  validates :name, presence: true
  validates :slug, presence: true,
                   uniqueness: { scope: :account_id },
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: :invalid }
  validates :account_id, presence: true

  validate :validate_definition, if: -> { definition_changed? && definition.present? }
  validate :validate_required_fields, if: :should_validate_required_fields?

  before_validation :normalize_slug
  before_validation :apply_defaults, on: :create
  before_validation :normalize_branding

  scope :ordered, -> { order(updated_at: :desc) }

  def public_url
    frontend = ENV.fetch('FRONTEND_URL', '').chomp('/')
    "#{frontend}/public/forms/#{account_id}/#{slug}"
  end

  def submissions_count
    form_submissions_count
  end

  def publishable?
    draft? || paused?
  end

  def branding_for_api
    AccountForms::BrandingSanitizer.call(DEFAULT_BRANDING.merge(branding || {}))
  end

  private

  def normalize_slug
    return if slug.blank? && name.blank?

    self.slug = (slug.presence || name).to_s.parameterize
  end

  def validate_definition
    return if definition.blank? || !definition.key?('fields')

    validator = AccountForms::DefinitionValidator.new(definition, account)
    return if validator.valid?

    validator.errors.each { |msg| errors.add(:definition, msg) }
  end

  def validate_required_fields
    fields = definition.fetch('fields', [])
    return if fields.any? { |field| field_required?(field) }

    errors.add(:base, I18n.t('account_forms.errors.no_required_fields'))
  end

  def should_validate_required_fields?
    return false if definition.blank? || !definition.key?('fields')

    definition_changed? || transitioning_to_published?
  end

  def field_required?(field)
    ActiveModel::Type::Boolean.new.cast(field['required'])
  end

  def transitioning_to_published?
    will_save_change_to_status? && published?
  end

  def apply_defaults
    self.definition = DEFAULT_DEFINITION.deep_dup if definition.blank?
    self.settings = DEFAULT_SETTINGS.merge(settings || {})
  end

  def normalize_branding
    current = branding.is_a?(Hash) ? branding.stringify_keys : {}
    if new_record? && current['header_title'].blank? && name.present?
      current = current.merge('header_title' => name)
    end
    self.branding = AccountForms::BrandingSanitizer.call(DEFAULT_BRANDING.merge(current))
  end
end
