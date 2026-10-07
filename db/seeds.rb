# loading installation configs
GlobalConfig.clear_cache
ConfigLoader.new.process

## Seeds productions
if Rails.env.production?
  # Setup Onboarding flow
  Redis::Alfred.set(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING, true)
end

## Seeds for Local Development
unless Rails.env.production?

  # Enables creating additional accounts from dashboard
  installation_config = InstallationConfig.find_or_initialize_by(name: 'CREATE_NEW_ACCOUNT_FROM_DASHBOARD')
  installation_config.value = true
  installation_config.save!
  GlobalConfig.clear_cache

  account = Account.find_or_create_by!(name: 'Acme Inc')
  account.enable_features!('custom_roles', 'workflows')

  secondary_account = Account.find_or_create_by!(name: 'Acme Org')
  secondary_account.enable_features!('custom_roles')

  user = User.find_or_initialize_by(email: 'john@acme.inc')
  user.name = 'John'
  user.password = 'Password1!'
  user.password_confirmation = 'Password1!'
  user.type = 'SuperAdmin'
  user.skip_confirmation!
  user.save!
  # user.access_token.update!(token: ENV['SUPER_ADMIN_ACCESS_TOKEN']) if ENV['SUPER_ADMIN_ACCESS_TOKEN']

  AccountUser.find_or_create_by!(account_id: account.id, user_id: user.id) do |membership|
    membership.role = :administrator
  end

  AccountUser.find_or_create_by!(account_id: secondary_account.id, user_id: user.id) do |membership|
    membership.role = :administrator
  end

  web_widget = Channel::WebWidget.find_or_create_by!(account: account, website_url: 'https://acme.inc')
  inbox = Inbox.find_or_create_by!(account: account, name: 'Acme Support') do |record|
    record.channel = web_widget
  end
  InboxMember.find_or_create_by!(user: user, inbox: inbox)

  unless account.conversations.exists?
    contact_inbox = ContactInboxWithContactBuilder.new(
      source_id: user.id,
      inbox: inbox,
      hmac_verified: true,
      contact_attributes: { name: 'jane', email: 'jane@example.com', phone_number: '+2320000' }
    ).perform

    conversation = Conversation.create!(
      account: account,
      inbox: inbox,
      status: :open,
      assignee: user,
      contact: contact_inbox.contact,
      contact_inbox: contact_inbox,
      additional_attributes: {}
    )

    Seeders::MessageSeeder.create_sample_email_collect_message conversation

    Message.create!(content: 'Hello', account: account, inbox: inbox, conversation: conversation, sender: contact_inbox.contact,
                    message_type: :incoming)

    location_message = Message.new(content: 'location', account: account, inbox: inbox, sender: contact_inbox.contact, conversation: conversation,
                                   message_type: :incoming)
    location_message.attachments.new(
      account_id: account.id,
      file_type: 'location',
      coordinates_lat: 37.7893768,
      coordinates_long: -122.3895553,
      fallback_title: 'Bay Bridge, San Francisco, CA, USA'
    )
    location_message.save!

    Seeders::MessageSeeder.create_sample_cards_message conversation
    Seeders::MessageSeeder.create_sample_input_select_message conversation
    Seeders::MessageSeeder.create_sample_form_message conversation
    Seeders::MessageSeeder.create_sample_articles_message conversation
    Seeders::MessageSeeder.create_sample_csat_collect_message conversation
  end

  CannedResponse.find_or_create_by!(account: account, short_code: 'start') do |record|
    record.content = 'Hello welcome to chatwoot.'
  end

  Seeders::WorkflowScheduleSeeder.new(account: account).perform!
end
