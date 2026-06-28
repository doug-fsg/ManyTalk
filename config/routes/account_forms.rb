# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      resources :accounts, only: [] do
        scope module: :accounts do
          resources :account_forms, only: [:index, :create, :show, :update, :destroy] do
            member do
              post :update_status
              get :submissions
              get :export_submissions
            end
          end
        end
      end
    end
  end

  namespace :public, defaults: { format: 'json' } do
    namespace :api do
      namespace :v1 do
        get 'account_forms/:account_id/:slug', to: 'account_forms#show'
        post 'account_forms/:account_id/:slug/submit', to: 'account_forms#submit'
      end
    end
  end

  get 'public/forms/:account_id/:slug', to: 'public/forms#show', as: :public_form_page
end
