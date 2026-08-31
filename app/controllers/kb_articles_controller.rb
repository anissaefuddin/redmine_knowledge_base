# frozen_string_literal: true

class KbArticlesController < ApplicationController
  before_action :require_login
  before_action :find_article, only: %i[show edit update destroy history version add_project remove_project]
  before_action :authorize_view, only: %i[show history version]
  before_action :require_admin, only: %i[new create edit update destroy add_project remove_project]

  helper :knowledge_base
  helper :attachments

  def show
    @linked_projects = @article.projects.order(:name)
  end

  def new
    @article = KbArticle.new(kb_category_id: params[:kb_category_id])
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
  end

  def version
    @version = @article.kb_article_versions.find_by!(version: params[:version])
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
    params.require(:kb_article).permit(:title, :content, :kb_category_id)
  end
end
