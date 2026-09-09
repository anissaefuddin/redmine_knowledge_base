# frozen_string_literal: true

module RedmineKnowledgeBase
  # Shared permission checks for the plugin's 3 controllers and their views.
  # Every check goes through User#allowed_to?(..., nil, global: true) - admins
  # are always granted (Redmine's own behavior), everyone else needs the
  # matching permission from Administration > Roles and permissions >
  # Knowledge base, set per role.
  module Authorization
    extend ActiveSupport::Concern

    included do
      helper_method :kb_manage_articles?, :kb_manage_categories?, :kb_manage_tags? if respond_to?(:helper_method)
    end

    def kb_manage_articles?(user = User.current)
      user.allowed_to?(:manage_kb_articles, nil, global: true)
    end

    def kb_manage_categories?(user = User.current)
      user.allowed_to?(:manage_kb_categories, nil, global: true)
    end

    def kb_manage_tags?(user = User.current)
      user.allowed_to?(:manage_kb_tags, nil, global: true)
    end

    def require_kb_manage_articles
      render_403 unless kb_manage_articles?
    end

    def require_kb_manage_categories
      render_403 unless kb_manage_categories?
    end

    def require_kb_manage_tags
      render_403 unless kb_manage_tags?
    end
  end
end
