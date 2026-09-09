class Api::V1::Accounts::ContactsController < Api::V1::Accounts::BaseController
  include Sift
  sort_on :email, type: :string
  sort_on :name, internal_name: :order_on_name, type: :scope, scope_params: [:direction]
  sort_on :phone_number, type: :string
  sort_on :last_activity_at, internal_name: :order_on_last_activity_at, type: :scope, scope_params: [:direction]
  sort_on :created_at, internal_name: :order_on_created_at, type: :scope, scope_params: [:direction]
  sort_on :company, internal_name: :order_on_company_name, type: :scope, scope_params: [:direction]
  sort_on :city, internal_name: :order_on_city, type: :scope, scope_params: [:direction]
  sort_on :country, internal_name: :order_on_country_name, type: :scope, scope_params: [:direction]

  RESULTS_PER_PAGE = 15
  MAX_PER_PAGE = 200 # Limite para carregamento em lote (Kanban com muitos contatos)

  before_action :check_authorization
  before_action :set_current_page, only: [:index, :active, :search, :filter]
  before_action :fetch_contact, only: [:show, :update, :destroy, :avatar, :contactable_inboxes, :destroy_custom_attributes]
  before_action :set_include_contact_inboxes, only: [:index, :search, :filter]

  def index
    @contacts_count = resolved_contacts.count
    @contacts = fetch_contacts(resolved_contacts)
  end

  def search
    render json: { error: 'Specify search string with parameter q' }, status: :unprocessable_entity if params[:q].blank? && return

    query = params[:q].strip
    contacts = resolved_contacts.where(
      'name ILIKE :search OR email ILIKE :search OR phone_number ILIKE :search OR contacts.identifier LIKE :search
        OR contacts.additional_attributes->>\'company_name\' ILIKE :search',
      search: "%#{query}%"
    )

    phone_variants = Contacts::BrazilPhoneNormalizer.e164_lookup_variants(query)
    if phone_variants.present?
      contacts = contacts.or(resolved_contacts.where(phone_number: phone_variants))
    end

    @contacts_count = contacts.count
    @contacts = fetch_contacts(contacts)
  end

  def import
    render json: { error: I18n.t('errors.contacts.import.failed') }, status: :unprocessable_entity and return if params[:import_file].blank?

    ActiveRecord::Base.transaction do
      import = Current.account.data_imports.create!(data_type: 'contacts')
      import.import_file.attach(params[:import_file])
    end

    head :ok
  end

  def export
    export_service = build_export_service
    if export_service.direct_download?
      send_data export_service.to_csv,
                filename: "contacts_#{Current.account.id}_#{Time.zone.today}.csv",
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    else
      Account::ContactsExportJob.perform_later(
        Current.account.id,
        Current.user.id,
        params['column_names'],
        export_filter_params
      )
      render json: {
        export_mode: 'email',
        message: I18n.t('errors.contacts.export.success')
      }, status: :accepted
    end
  end

  def export_preview
    export_service = build_export_service
    render json: {
      count: export_service.count,
      mode: export_service.export_mode,
      limit: Contacts::ExportService::DIRECT_DOWNLOAD_LIMIT
    }
  end

  # returns online contacts
  def active
    contacts = Current.account.contacts.where(id: ::OnlineStatusTracker
                  .get_available_contact_ids(Current.account.id))
    @contacts_count = contacts.count
    @contacts = contacts.page(@current_page)
  end

  def show; end

  def filter
    result = ::Contacts::FilterService.new(Current.account, Current.user, params.permit!).perform
    contacts = result[:contacts]
    contacts = filter_by_account_form(contacts) if params[:account_form_id].present?
    @contacts_count = contacts.count
    @contacts = fetch_contacts(contacts)
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidValue => e
    render_could_not_create_error(e.message)
  end

  def contactable_inboxes
    @all_contactable_inboxes = Contacts::ContactableInboxesService.new(contact: @contact).get
    @contactable_inboxes = @all_contactable_inboxes.select { |contactable_inbox| policy(contactable_inbox[:inbox]).show? }
  end

  # TODO : refactor this method into dedicated contacts/custom_attributes controller class and routes
  def destroy_custom_attributes
    @contact.custom_attributes = @contact.custom_attributes.excluding(params[:custom_attributes])
    @contact.save!
  end

  def create
    ActiveRecord::Base.transaction do
      @contact = find_or_build_contact
      @contact.assign_attributes(permitted_params.except(:avatar_url))
      @contact.save!
      @contact_inbox = build_contact_inbox
      process_avatar_from_url
    end
  rescue ActiveRecord::RecordNotUnique => e
    render_contact_not_unique(e)
  end

  def update
    @contact.assign_attributes(contact_update_params)
    Contact.transaction do
      sync_whatsapp_contact_inbox_source_ids
      @contact.save!
    end
    process_avatar_from_url
  rescue ActiveRecord::RecordNotUnique => e
    render_contact_not_unique(e)
  end

  def destroy
    if ::OnlineStatusTracker.get_presence(
      @contact.account.id, 'Contact', @contact.id
    )
      return render_error({ message: I18n.t('contacts.online.delete', contact_name: @contact.name.capitalize) },
                          :unprocessable_entity)
    end

    @contact.destroy!
    head :ok
  end

  def avatar
    @contact.avatar.purge if @contact.avatar.attached?
    @contact
  end

  private

  def build_export_service
    Contacts::ExportService.new(
      account: Current.account,
      account_user: Current.account_user,
      params: export_filter_params,
      column_names: params['column_names']
    )
  end

  def export_filter_params
    permitted = params.permit(:label, :account_form_id, column_names: [], payload: {})
    # payload is an array of filter hashes; permit! keeps nested structure for FilterService
    {
      payload: params[:payload],
      label: permitted[:label],
      account_form_id: permitted[:account_form_id]
    }
  end

  # TODO: Move this to a finder class
  def resolved_contacts
    return @resolved_contacts if @resolved_contacts

    @resolved_contacts = Current.account.contacts.resolved_contacts

    @resolved_contacts = @resolved_contacts.tagged_with(params[:labels], any: true) if params[:labels].present?
    @resolved_contacts = filter_by_account_form(@resolved_contacts) if params[:account_form_id].present?
    @resolved_contacts
  end

  def filter_by_account_form(relation)
    form_id = params[:account_form_id].to_i
    return relation.none if form_id.zero?

    relation
      .joins(:form_submissions)
      .where(form_submissions: { account_form_id: form_id })
      .distinct
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def fetch_contacts(contacts)
    per_page = [params[:per_page].to_i, MAX_PER_PAGE].min
    per_page = RESULTS_PER_PAGE if per_page <= 0
    contacts_with_avatar = filtrate(contacts)
                           .includes([{ avatar_attachment: [:blob] }])
                           .page(@current_page).per(per_page)

    contacts_with_avatar = contacts_with_avatar.includes(contact_pipeline_positions: :assignee)
    return contacts_with_avatar.includes([{ contact_inboxes: [:inbox] }]) if @include_contact_inboxes

    contacts_with_avatar
  end

  def find_or_build_contact
    phone_number = permitted_params[:phone_number]
    if phone_number.present?
      existing = Contacts::BrazilPhoneNormalizer.find_contact(
        account: Current.account,
        phone_number: phone_number
      )
      return existing if existing
    end

    identifier = permitted_params[:identifier]
    if identifier.present?
      existing = Current.account.contacts.find_by(identifier: identifier)
      return existing if existing
    end

    Current.account.contacts.new
  end

  def sync_whatsapp_contact_inbox_source_ids
    return if @contact.phone_number.blank?

    source_id = @contact.phone_number.delete('+').to_s
    return if source_id.blank?

    @contact.contact_inboxes.each do |contact_inbox|
      next unless contact_inbox.inbox.channel_type == 'Channel::Whatsapp'
      next if contact_inbox.source_id == source_id
      next if ContactInbox.where(inbox_id: contact_inbox.inbox_id, source_id: source_id).where.not(id: contact_inbox.id).exists?

      contact_inbox.update_attribute(:source_id, source_id)
    end
  end

  def render_contact_not_unique(exception)
    attribute = if exception.message.include?('uniq_identifier_per_account_contact')
                  :identifier
                elsif exception.message.include?('index_contact_inboxes_on_inbox_id_and_source_id')
                  :phone_number
                else
                  :base
                end

    @contact ||= Current.account.contacts.new
    @contact.errors.add(attribute, :taken)
    render_record_invalid(ActiveRecord::RecordInvalid.new(@contact))
  end

  def build_contact_inbox
    return if params[:inbox_id].blank?

    inbox = Current.account.inboxes.find(params[:inbox_id])
    ContactInboxBuilder.new(
      contact: @contact,
      inbox: inbox,
      source_id: params[:source_id]
    ).perform
  end

  def permitted_params
    params.permit(:id, :name, :identifier, :email, :phone_number, :avatar, :blocked, :avatar_url, additional_attributes: {}, custom_attributes: {})
  end

  def contact_custom_attributes
    return @contact.custom_attributes.merge(permitted_params[:custom_attributes]) if permitted_params[:custom_attributes]

    @contact.custom_attributes
  end

  def contact_update_params
    # we want the merged custom attributes not the original one
    permitted_params.except(:custom_attributes, :avatar_url).merge({ custom_attributes: contact_custom_attributes })
  end

  def set_include_contact_inboxes
    @include_contact_inboxes = if params[:include_contact_inboxes].present?
                                 params[:include_contact_inboxes] == 'true'
                               else
                                 true
                               end
  end

  def fetch_contact
    @contact = Current.account.contacts
                        .includes(contact_inboxes: [:inbox], contact_pipeline_positions: [])
                        .find(params[:id])
  end

  def process_avatar_from_url
    ::Avatar::AvatarFromUrlJob.perform_later(@contact, params[:avatar_url]) if params[:avatar_url].present?
  end

  def render_error(error, error_status)
    render json: error, status: error_status
  end
end