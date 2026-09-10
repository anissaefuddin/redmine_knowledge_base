# frozen_string_literal: true

require 'redmine'
require_relative 'lib/redmine_knowledge_base/authorization'
require_relative 'lib/redmine_knowledge_base/hooks/views_layouts_hook'
require_relative 'lib/redmine_knowledge_base/macros'

Redmine::Plugin.register :redmine_knowledge_base do
  name 'Redmine Knowledge Base'
  author 'anissaefuddin'
  description 'Cross-project knowledge base: a single source of truth for documentation referenced across multiple projects.'
  version '0.2.0'
  url 'https://github.com/anissaefuddin/redmine_knowledge_base'
  author_url 'https://github.com/anissaefuddin'

  requires_redmine version_or_higher: '6.1'

  # All four permissions below are checked with
  # allowed_to?(:permission_name, nil, global: true) everywhere in the
  # plugin - never with a Project context - so wrapping them in
  # project_module here has no effect on authorization (Redmine's global
  # permission check never looks at project_module/module-enablement, see
  # User#allowed_to?). It's here purely so they show up grouped under a
  # "Knowledge base" heading in Administration > Roles and permissions,
  # instead of scattered/unlabeled among project permissions. Granted per
  # role via Settings > Roles (including the built-in "Non member" role,
  # so it can reach users regardless of which projects they belong to).
  project_module :knowledge_base do
    permission :view_knowledge_base,
               { knowledge_base: [:index], kb_categories: [:show],
                 kb_articles: [:show, :history, :version, :diff], kb_synced_blocks: [:show],
                 kb_saved_searches: %i[create destroy] },
               read: true

    # Contributor tier: create articles and edit ones they authored. Kept as
    # two separate permissions (rather than a single "contribute") so a role
    # can be given just one of the two if needed - e.g. a role that may
    # draft new articles but never touch someone else's.
    permission :add_kb_articles,
               { kb_articles: %i[new create duplicate], kb_uploads: [:create],
                 kb_link_previews: [:show], kb_synced_blocks: [:update], kb_tags: [:quick_create] }

    permission :edit_own_kb_articles,
               { kb_articles: %i[edit update], kb_uploads: [:create],
                 kb_link_previews: [:show], kb_synced_blocks: [:update], kb_tags: [:quick_create] }

    # Editor tier: superset of the two Contributor permissions above, plus
    # edit/delete/pin/restore on EVERY article regardless of author. Deliberately
    # keeps the full action list (not just the "everyone else's article" actions)
    # so existing roles that already have manage_kb_articles granted keep every
    # capability they had before add_kb_articles/edit_own_kb_articles existed,
    # with no migration needed.
    permission :manage_kb_articles,
               { kb_articles: %i[new create duplicate edit update destroy restore_version
                                  add_project remove_project add_related remove_related toggle_pin
                                  trash restore destroy_permanently],
                 kb_uploads: [:create], kb_link_previews: [:show], kb_synced_blocks: [:update],
                 kb_tags: [:quick_create] }

    permission :manage_kb_categories,
               { kb_categories: %i[index new create edit update destroy] }

    permission :manage_kb_tags,
               { kb_tags: %i[index new create edit update destroy] }
  end

  menu :application_menu, :knowledge_base,
       { controller: 'knowledge_base', action: 'index' },
       caption: :label_knowledge_base,
       if: Proc.new { User.current.allowed_to?(:view_knowledge_base, nil, global: true) }
end
