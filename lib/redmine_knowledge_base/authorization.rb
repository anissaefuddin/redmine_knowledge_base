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
      helper_method :kb_manage_articles?, :kb_manage_categories?, :kb_manage_tags?,
                    :kb_add_articles?, :kb_edit_article?, :kb_can_upload? if respond_to?(:helper_method)
    end

    # Editor/Admin tier: create/edit/delete/pin/restore on EVERY article.
    def kb_manage_articles?(user = User.current)
      user.allowed_to?(:manage_kb_articles, nil, global: true)
    end

    def kb_manage_categories?(user = User.current)
      user.allowed_to?(:manage_kb_categories, nil, global: true)
    end

    def kb_manage_tags?(user = User.current)
      user.allowed_to?(:manage_kb_tags, nil, global: true)
    end

    # Contributor tier and up: allowed to create new articles at all.
    def kb_add_articles?(user = User.current)
      kb_manage_articles?(user) || user.allowed_to?(:add_kb_articles, nil, global: true)
    end

    # Editor/Admin can edit any article; a Contributor can only edit one they
    # authored themselves. `article` may be nil (e.g. the "can I edit
    # something" question before one exists) - only the manage_kb_articles
    # check makes sense then, since ownership has no meaning without a record.
    def kb_edit_article?(article, user = User.current)
      return true if kb_manage_articles?(user)
      return false unless article && user.allowed_to?(:edit_own_kb_articles, nil, global: true)

      article.author_id == user.id
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

    def require_kb_add_articles
      render_403 unless kb_add_articles?
    end

    def require_kb_edit_article
      render_403 unless kb_edit_article?(@article)
    end

    # Anyone who could conceivably be editing article content right now:
    # Contributor drafting a new article, Contributor/Editor/Admin editing
    # an existing one. Deliberately not article-scoped (unlike
    # kb_edit_article?) - the block editor uploads inline images before a
    # brand new article has even been saved once.
    def kb_can_upload?(user = User.current)
      kb_add_articles?(user) || user.allowed_to?(:edit_own_kb_articles, nil, global: true)
    end

    def require_kb_can_upload
      render_403 unless kb_can_upload?
    end
  end
end
