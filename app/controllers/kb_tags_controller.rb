# frozen_string_literal: true

class KbTagsController < ApplicationController
  menu_item :knowledge_base

  before_action :require_login
  before_action :require_admin
  before_action :find_tag, only: %i[edit update destroy]

  def index
    @tags = KbTag.sorted
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
