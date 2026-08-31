# frozen_string_literal: true

get 'knowledge_base', to: 'knowledge_base#index', as: 'knowledge_base'

resources :kb_categories, only: %i[new create edit update destroy]

resources :kb_articles, only: %i[show new create edit update destroy] do
  member do
    get :history
    get 'versions/:version', action: :version, as: 'version'
    post 'projects', action: :add_project, as: 'add_project'
    delete 'projects/:project_id', action: :remove_project, as: 'remove_project'
  end
end
