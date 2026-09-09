# frozen_string_literal: true

class KbTagsController < ApplicationController
  include RedmineKnowledgeBase::Authorization

  helper :sort
  include SortHelper

  menu_item :knowledge_base

  before_action :require_login
  before_action :require_kb_manage_tags
  before_action :find_tag, only: %i[edit update destroy]

  def index
    filtered = KbTag.all
    if params[:q].present?
      @q = params[:q].to_s.strip
      filtered = filtered.where('LOWER(kb_tags.name) LIKE ?', "%#{@q.downcase}%")
    end

    # Count on the plain (unselected) scope - ActiveRecord's automatic
    # count-SQL-wrapping chokes on the raw "AS articles_count" select added
    # below, so the item count for pagination is computed separately here
    # rather than via Redmine's `paginate` helper (which would call
    # .count on the annotated scope).
    @tag_pages = paginator(filtered.count)

    # A correlated subquery (rather than LEFT JOIN + GROUP BY) keeps the
    # page query one-row-per-tag, so sorting by article count is a plain
    # ORDER BY on a real selected column instead of needing a GROUP BY.
    articles_count_sql = KbArticleTag.where('kb_article_tags.kb_tag_id = kb_tags.id').select('COUNT(*)').to_sql
    scope = filtered.select("kb_tags.*, (#{articles_count_sql}) AS articles_count")

    sort_init 'name', 'asc'
    sort_update('name' => 'kb_tags.name', 'position' => 'kb_tags.position', 'articles' => 'articles_count')
    scope = scope.reorder(sort_clause)

    @tags = scope.limit(@tag_pages.per_page).offset(@tag_pages.offset).to_a
  end

  def new
    @tag = KbTag.new
  end

  def create
    @tag = KbTag.new(tag_params)
    if @tag.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to kb_tags_path
    else
      render :new
    end
  end

  def edit; end

  def update
    if @tag.update(tag_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to kb_tags_path
    else
      render :edit
    end
  end

  def destroy
    if @tag.kb_articles.exists?
      flash[:error] = l(:error_kb_tag_not_empty)
    else
      @tag.destroy
      flash[:notice] = l(:notice_successful_delete)
    end
    redirect_to kb_tags_path
  end

  private

  def find_tag
    @tag = KbTag.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def tag_params
    params.require(:kb_tag).permit(:name, :position)
  end
end
