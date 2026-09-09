# frozen_string_literal: true

class KbArticlesController < ApplicationController
  include RedmineKnowledgeBase::Authorization

  menu_item :knowledge_base

  before_action :require_login
  before_action :find_article, only: %i[show edit update destroy history version diff restore_version add_project remove_project add_related remove_related toggle_pin duplicate]
  before_action :authorize_view, only: %i[show history version diff duplicate]
  before_action :require_kb_add_articles, only: %i[new create duplicate]
  before_action :require_kb_edit_article, only: %i[edit update]
  before_action :require_kb_manage_articles, only: %i[destroy restore_version add_project remove_project add_related remove_related toggle_pin]

  helper :knowledge_base
  helper :attachments

  def show
    @linked_projects = @article.projects.order(:name)
    @related_articles = @article.related_articles.select { |a| a.visible?(User.current) }
    @referenced_by = @article.referenced_by.select { |a| a.visible?(User.current) }
    @breadcrumb = @article.kb_category.self_and_ancestors
    @counts_by_category_id = KbArticle.group(:kb_category_id).count
    @category_tree = KbCategory.build_tree(KbCategory.sorted.to_a)
    # Bypasses validations/callbacks so a view doesn't touch updated_at or
    # trigger KbArticle#snapshot_version. authorize_view already gated
    # visibility before this action runs.
    @article.update_column(:views_count, @article.views_count + 1)
  end

  def new
    @article = KbArticle.new(kb_category_id: params[:kb_category_id], status: 'draft')
  end

  def create
    @article = KbArticle.new(article_params)
    @article.author = User.current
    @article.updated_by = User.current
    @article.save_attachments(params[:attachments])
    if @article.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to kb_article_path(@article)
    else
      render :new
    end
  end

  def edit; end

  def update
    @article.updated_by = User.current
    @article.save_attachments(params[:attachments])
    if @article.update(article_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to kb_article_path(@article)
    else
      render :edit
    end
  end

  def destroy
    @article.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to knowledge_base_path
  end

  def history
    @versions = @article.kb_article_versions
    @breadcrumb = @article.kb_category.self_and_ancestors
  end

  def version
    @version = @article.kb_article_versions.find_by!(version: params[:version])
    @breadcrumb = @article.kb_category.self_and_ancestors
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Word-level diff between an old version's content and the article's
  # current live content, so a reader can see what's changed since that
  # version without having to eyeball two full-text pages side by side.
  def diff
    @version = @article.kb_article_versions.find_by!(version: params[:version])
    @breadcrumb = @article.kb_category.self_and_ancestors
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Overwrites the article's current title/content with an old version's,
  # going through the normal update path so the state being replaced is
  # itself snapshotted by KbArticle#snapshot_version first - restoring is
  # just another edit, never destructive of history.
  def restore_version
    version = @article.kb_article_versions.find_by!(version: params[:version])
    @article.updated_by = User.current
    if @article.update(title: version.title, content: version.content)
      flash[:notice] = l(:notice_kb_version_restored, number: version.version)
    else
      flash[:error] = l(:error_kb_version_restore_failed)
    end
    redirect_to kb_article_path(@article)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def add_project
    project = Project.find(params[:project_id])
    @article.projects << project unless @article.projects.exists?(project.id)
    redirect_to kb_article_path(@article)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def remove_project
    @article.kb_article_projects.where(project_id: params[:project_id]).destroy_all
    redirect_to kb_article_path(@article)
  end

  def add_related
    related = KbArticle.find(params[:related_id].presence)
    @article.related_articles << related unless @article.related_articles.exists?(related.id) || related.id == @article.id
    redirect_to kb_article_path(@article)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def remove_related
    @article.kb_article_relations.where(related_kb_article_id: params[:related_id]).destroy_all
    redirect_to kb_article_path(@article)
  end

  def toggle_pin
    now_pinned = !@article.pinned?
    @article.update_column(:pinned_at, now_pinned ? Time.current : nil)
    flash[:notice] = now_pinned ? l(:notice_kb_pinned) : l(:notice_kb_unpinned)
    redirect_to kb_article_path(@article)
  end

  # Clones title/content/category/tags into a brand new draft owned by the
  # current user, then sends them straight to editing it. Doesn't copy
  # pin state, view count, version history, related-article/project links,
  # or attachments - those are specific to the original article's own
  # lifecycle, not something a copy should inherit.
  def duplicate
    copy = KbArticle.new(
      title: "#{l(:text_kb_copy_of)} #{@article.title}",
      content: @article.content,
      kb_category_id: @article.kb_category_id,
      status: 'draft',
      author: User.current,
      updated_by: User.current
    )
    copy.tag_ids = @article.tag_ids
    if copy.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to edit_kb_article_path(copy)
    else
      flash[:error] = copy.errors.full_messages.join(', ')
      redirect_to kb_article_path(@article)
    end
  end

  private

  def find_article
    @article = KbArticle.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_view
    render_403 unless @article.visible?(User.current)
  end

  def article_params
    params.require(:kb_article).permit(:title, :content, :kb_category_id, :status, tag_ids: [])
  end
end
