# frozen_string_literal: true

get 'knowledge_base', to: 'knowledge_base#index', as: 'knowledge_base'

resources :kb_categories, only: %i[index show new create edit update destroy]

resources :kb_tags, only: %i[index new create edit update destroy]

resources :kb_articles, only: %i[show new create edit update destroy] do
  member do
    get :history
    get 'versions/:version', action: :version, as: 'version'
    post 'versions/:version/restore', action: :restore_version, as: 'restore_version'
    post 'projects', action: :add_project, as: 'add_project'
    delete 'projects/:project_id', action: :remove_project, as: 'remove_project'
    post 'related', action: :add_related, as: 'add_related'
    delete 'related/:related_id', action: :remove_related, as: 'remove_related'
    post :toggle_pin
  end
end
