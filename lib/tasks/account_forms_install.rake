# frozen_string_literal: true

namespace :account_forms do
  desc 'Add account_forms routes to config/routes.rb (run once, then remove config/initializers/account_forms_routes.rb if desired)'
  task install_routes: :environment do
    routes_path = Rails.root.join('config/routes.rb')
    text = routes_path.read

    if text.include?('resources :account_forms')
      puts 'account_forms routes already present in config/routes.rb'
      next
    end

    api_block = <<~RUBY.chomp
          resources :account_forms, only: [:index, :create, :show, :update, :destroy] do
            member do
              post :update_status
              get :submissions
            end
          end
    RUBY

    text.sub!(
      "          resources :workflows, only: [:index, :create, :show, :update, :destroy] do",
      "#{api_block}\n          resources :workflows, only: [:index, :create, :show, :update, :destroy] do"
    )

    public_block = <<~RUBY.chomp
        get 'account_forms/:account_id/:slug', to: 'account_forms#show'
        post 'account_forms/:account_id/:slug/submit', to: 'account_forms#submit'
    RUBY

    text.sub!(
      "        resources :csat_survey, only: [:show, :update]",
      "#{public_block}\n\n        resources :csat_survey, only: [:show, :update]"
    )

    unless text.include?("get 'public/forms/:account_id/:slug'")
      text.sub!(
        "  get 'hc/:slug', to: 'public/api/v1/portals#show'",
        "  get 'public/forms/:account_id/:slug', to: 'public/forms#show', as: :public_form_page\n\n  get 'hc/:slug', to: 'public/api/v1/portals#show'"
      )
    end

    routes_path.write(text)
    puts 'Patched config/routes.rb — restart the backend (overmind restart backend)'
  end
end
