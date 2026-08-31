# frozen_string_literal: true

require 'redmine'
require_relative 'lib/redmine_knowledge_base/hooks/views_layouts_hook'

Redmine::Plugin.register :redmine_knowledge_base do
  name 'Redmine Knowledge Base'
  author 'anissaefuddin'
  description 'Cross-project knowledge base: a single source of truth for documentation referenced across multiple projects.'
  version '0.1.0'
  url 'https://github.com/anissaefuddin/redmine_knowledge_base'
  author_url 'https://github.com/anissaefuddin'

  requires_redmine version_or_higher: '6.1'

  # Global permission, deliberately declared outside any project_module block:
  # the knowledge base is not scoped to a single project, so visibility must not
  # depend on project membership. Granted via Settings > Roles (including the
  # built-in "Non member" role, so it can reach users regardless of which
  # projects they belong to) and checked with allowed_to?(:view_knowledge_base, nil, global: true).
  permission :view_knowledge_base,
             { knowledge_base: [:index], kb_articles: [:show, :history, :version] },
             read: true

  menu :application_menu, :knowledge_base,
       { controller: 'knowledge_base', action: 'index' },
       caption: :label_knowledge_base,
       if: Proc.new { User.current.admin? || User.current.allowed_to?(:view_knowledge_base, nil, global: true) }
end
