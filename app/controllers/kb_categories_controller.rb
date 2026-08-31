# frozen_string_literal: true

class KbCategoriesController < ApplicationController
  before_action :require_login
  before_action :require_admin
  before_action :find_category, only: %i[edit update destroy]

  def new
    @category = KbCategory.new
  end

  def create
    @category = KbCategory.new(category_params)
    if @category.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to knowledge_base_path
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
      redirect_to knowledge_base_path
    else
      @all_groups = Group.sorted
      render :edit
    end
  end

  def destroy
    if @category.kb_articles.exists?
      flash[:error] = l(:error_kb_category_not_empty)
    else
      @category.destroy
      flash[:notice] = l(:notice_successful_delete)
    end
    redirect_to knowledge_base_path
  end

  private

  def find_category
    @category = KbCategory.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def category_params
    params.require(:kb_category).permit(:name, :description, :position)
  end
end
