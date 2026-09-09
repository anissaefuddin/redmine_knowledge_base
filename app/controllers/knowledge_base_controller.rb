# frozen_string_literal: true

class KnowledgeBaseController < ApplicationController
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
    @pinned_articles = @pinned_articles.published unless User.current.admin?

    if params[:q].present?
      @q = params[:q].to_s.strip
      like = "%#{@q.downcase}%"
      @articles = KbArticle.where(kb_category_id: @visible_category_ids)
                            .where('LOWER(title) LIKE :q OR LOWER(content) LIKE :q', q: like)
      @articles = @articles.published unless User.current.admin?
      @articles = @articles.order(:title).limit(50)
    end
  end

  private

  def authorize_global_view
    render_403 unless User.current.admin? || User.current.allowed_to?(:view_knowledge_base, nil, global: true)
  end
end
