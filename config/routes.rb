# frozen_string_literal: true

get 'knowledge_base', to: 'knowledge_base#index', as: 'knowledge_base'

# format: false so this route never captures a :format segment - a request
# ending in .json/.xml would otherwise make Rails treat it as an API
# request and skip session-cookie auth entirely (see KbUploadsController's
# comment for why that matters here).
post 'kb_uploads', to: 'kb_uploads#create', as: 'kb_uploads', format: false
get 'kb_link_previews', to: 'kb_link_previews#show', as: 'kb_link_previews', format: false

resources :kb_categories, only: %i[index show new create edit update destroy]

resources :kb_tags, only: %i[index new create edit update destroy]
post 'kb_tags/quick_create', to: 'kb_tags#quick_create', as: 'quick_create_kb_tag', format: false

resources :kb_articles, only: %i[show new create edit update destroy] do
  member do
    get :history
    get 'versions/:version', action: :version, as: 'version'
    # version (and optional compare_to) are query params, not path segments,
    # so a plain GET <select> form on the History page can drive an
    # arbitrary version-vs-version compare without any JS to build the URL.
    get 'versions/diff', action: :diff, as: 'diff_version'
    post 'versions/:version/restore', action: :restore_version, as: 'restore_version'
    post 'projects', action: :add_project, as: 'add_project'
    delete 'projects/:project_id', action: :remove_project, as: 'remove_project'
    post 'related', action: :add_related, as: 'add_related'
    delete 'related/:related_id', action: :remove_related, as: 'remove_related'
    post :toggle_pin
    post :duplicate
    post :restore
    delete :destroy_permanently
  end
  collection do
    get :trash
  end
end

resources :kb_synced_blocks, only: %i[show update], param: :id, constraints: { id: /[a-zA-Z0-9_-]+/ }

resources :kb_saved_searches, only: %i[create destroy]
