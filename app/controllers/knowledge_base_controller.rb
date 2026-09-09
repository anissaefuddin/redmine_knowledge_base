# frozen_string_literal: true

class KnowledgeBaseController < ApplicationController
  include RedmineKnowledgeBase::Authorization

  helper :sort
  include SortHelper

  menu_item :knowledge_base

  before_action :require_login
  before_action :authorize_global_view

  helper :knowledge_base

  def index
    all_categories = KbCategory.sorted.to_a
    @visible_category_ids = all_categories.select { |c| c.visible?(User.current) }.map(&:id)
    @counts_by_category_id = KbArticle.group(:kb_category_id).count
    @root_categories = KbCategory.build_tree(all_categories)

    @pinned_articles = KbArticle.pinned.where(kb_category_id: @visible_category_ids)
    @pinned_articles = @pinned_articles.published unless kb_manage_articles?

    @q = params[:q].to_s.strip
    @category_ids = Array(params[:category_ids]).reject(&:blank?).map(&:to_i)
    @tag_ids = Array(params[:tag_ids]).reject(&:blank?).map(&:to_i)
    @status_filter = kb_manage_articles? ? Array(params[:status]).reject(&:blank?) : []
    @searching = @q.present? || @category_ids.any? || @tag_ids.any? || @status_filter.any?

    if @searching
      search
    else
      landing
    end
  end

  private

  # Full-text search across title, content, category name and tag name -
  # not just the article title - plus optional category/tag/status filters.
  # Kept as ID-based subqueries (matching_category_ids/matching_article_ids_via_tag)
  # rather than joining kb_categories/kb_tags directly into the main scope,
  # so it composes cleanly with the separate tag_ids filter below (which
  # needs its own join) without ambiguous-column or duplicate-join issues.
  def search
    scope = KbArticle.where(kb_category_id: @visible_category_ids)
    scope = scope.published_or_authored_by(User.current) unless kb_manage_articles?

    if @q.present?
      like = "%#{@q.downcase}%"
      matching_category_ids = KbCategory.where('LOWER(name) LIKE ?', like).pluck(:id).presence || [0]
      matching_tag_ids = KbTag.where('LOWER(name) LIKE ?', like).pluck(:id)
      matching_article_ids_via_tag = KbArticleTag.where(kb_tag_id: matching_tag_ids).pluck(:kb_article_id).presence || [0]

      scope = scope.where(
        'LOWER(kb_articles.title) LIKE :q OR LOWER(kb_articles.content) LIKE :q OR ' \
        'kb_articles.kb_category_id IN (:cat_ids) OR kb_articles.id IN (:tag_article_ids)',
        q: like, cat_ids: matching_category_ids, tag_article_ids: matching_article_ids_via_tag
      )
    end

    scope = scope.where(kb_category_id: @category_ids) if @category_ids.any?
    scope = scope.joins(:kb_article_tags).where(kb_article_tags: { kb_tag_id: @tag_ids }).distinct if @tag_ids.any?
    scope = scope.where(status: @status_filter) if @status_filter.any?

    sort_init 'title', 'asc'
    sort_update('title' => 'kb_articles.title', 'updated_on' => 'kb_articles.updated_at', 'views' => 'kb_articles.views_count')
    scope = scope.reorder(sort_clause)

    @result_pages, @articles = paginate scope
    # Filter chip lists - every category/tag in the KB, not just ones already
    # matched, so a user can broaden or pivot the search from the results
    # screen instead of only narrowing it.
    @filterable_categories = KbCategory.where(id: @visible_category_ids).sorted
    @filterable_tags = KbTag.sorted
  end

  # No search/filter active: the actual landing page - recently updated,
  # most viewed, and category cards, in addition to the pinned section that
  # already existed. Each pulls from the same visible+published scope as
  # search, just ordered and capped differently.
  def landing
    base = KbArticle.where(kb_category_id: @visible_category_ids)
    base = base.published_or_authored_by(User.current) unless kb_manage_articles?

    @recent_articles = base.order(updated_at: :desc).limit(6)
    @popular_articles = base.order(views_count: :desc).limit(6)
    @category_cards = @root_categories
  end

  def authorize_global_view
    render_403 unless User.current.allowed_to?(:view_knowledge_base, nil, global: true)
  end
end
