# frozen_string_literal: true

class KbCategoriesController < ApplicationController
  menu_item :knowledge_base

  helper :sort
  include SortHelper

  before_action :require_login
  before_action :find_category, only: %i[show edit update destroy]
  before_action :authorize_view, only: %i[show]
  before_action :require_admin, except: %i[show]

  helper :knowledge_base

  # Admin management page: full category tree with edit/delete/add-subcategory
  # controls, mirroring KbTagsController#index.
  def index
    @category_tree = KbCategory.build_tree(KbCategory.sorted.to_a)
    @counts_by_category_id = KbArticle.group(:kb_category_id).count
  end

  # The "Daftar Artikel" browse page for one category: articles in this
  # category and all its descendants, with search/tag filter/sort/pagination.
  def show
    @ancestors = @category.ancestors
    @counts_by_category_id = KbArticle.group(:kb_category_id).count
    @category_tree = KbCategory.build_tree(KbCategory.sorted.to_a)
    visible_category_ids = @category.self_and_descendants.select { |c| c.visible?(User.current) }.map(&:id)

    scope = KbArticle.where(kb_category_id: visible_category_ids)
    scope = scope.published unless User.current.admin?
    @category_total_count = scope.count

    if params[:q].present?
      @q = params[:q].to_s.strip
      like = "%#{@q.downcase}%"
      scope = scope.where('LOWER(title) LIKE :q OR LOWER(content) LIKE :q', q: like)
    end

    @tag_ids = Array(params[:tag_ids]).reject(&:blank?).map(&:to_i)
    scope = scope.joins(:kb_article_tags).where(kb_article_tags: { kb_tag_id: @tag_ids }).distinct if @tag_ids.any?

    sort_init 'title', 'asc'
    sort_update('title' => 'kb_articles.title', 'updated_on' => 'kb_articles.updated_at', 'views' => 'kb_articles.views_count')
    scope = scope.reorder(sort_clause)

    @article_pages, @articles = paginate scope
    # Only tags actually used somewhere in this category (+ descendants),
    # not every tag in the whole knowledge base - keeps the filter chips
    # relevant to what's actually here instead of mostly-dead options.
    @tags = KbTag.joins(:kb_article_tags)
                 .where(kb_article_tags: { kb_article_id: KbArticle.where(kb_category_id: visible_category_ids) })
                 .distinct.sorted
  end

  def new
    @category = KbCategory.new(parent_id: params[:parent_id])
  end

  def create
    @category = KbCategory.new(category_params)
    if @category.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to kb_categories_path
    else
      render :new
    end
  end

  def edit
    @all_groups = Group.sorted
  end

  def update
    if @category.update(category_params)
      @category.group_ids = Array(params[:group_ids]).reject(&:blank?).map(&:to_i)
      flash[:notice] = l(:notice_successful_update)
      redirect_to kb_categories_path
    else
      @all_groups = Group.sorted
      render :edit
    end
  end

  def destroy
    if @category.kb_articles.exists? || @category.children.exists?
      flash[:error] = l(:error_kb_category_not_empty)
    else
      @category.destroy
      flash[:notice] = l(:notice_successful_delete)
    end
    redirect_to kb_categories_path
  end

  private

  def find_category
    @category = KbCategory.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_view
    render_403 unless @category.visible?(User.current)
  end

  def category_params
    params.require(:kb_category).permit(:name, :description, :position, :parent_id)
  end
end
