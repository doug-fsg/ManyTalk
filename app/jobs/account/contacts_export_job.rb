# frozen_string_literal: true

class Account::ContactsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, column_names, params)
    @account = Account.find(account_id)
    @account_user = @account.account_users.find_by!(user_id: user_id)
    Current.account = @account

    @export_service = Contacts::ExportService.new(
      account: @account,
      account_user: @account_user,
      params: params,
      column_names: column_names
    )

    attach_export_file(@export_service.to_csv)
    send_mail
  ensure
    Current.reset
  end

  private

  def attach_export_file(csv_data)
    return if csv_data.blank?

    @account.contacts_export.attach(
      io: StringIO.new(csv_data),
      filename: "#{@account.name}_#{@account.id}_contacts.csv",
      content_type: 'text/csv'
    )
  end

  def send_mail
    file_url = account_contact_export_url
    mailer = AdministratorNotifications::ChannelNotificationsMailer.with(account: @account)
    mailer.contact_export_complete(file_url, @account_user.user.email)&.deliver_later
  end

  def account_contact_export_url
    Rails.application.routes.url_helpers.rails_blob_url(@account.contacts_export)
  end
end
