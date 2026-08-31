# frozen_string_literal: true

class KnowledgeBaseController < ApplicationController
  before_action :require_login
  before_action :authorize_global_view

  helper :knowledge_base

  def index
    @categories = KbCategory.sorted.select { |c| c.visible?(User.current) }

    if params[:q].present?
      @q = params[:q].to_s.strip
      like = "%#{@q.downcase}%"
      @articles = KbArticle.where(kb_category_id: @categories.map(&:id))
                            .where('LOWER(title) LIKE :q OR LOWER(content) LIKE :q', q: like)
                            .order(:title)
                            .limit(50)
    end
  end

  private

  def authorize_global_view
    render_403 unless User.current.admin? || User.current.allowed_to?(:view_knowledge_base, nil, global: true)
  end
end
