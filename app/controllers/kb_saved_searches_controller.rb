# frozen_string_literal: true

# Lets a user save their current search filters (category/tag/status/q) as
# a named, reusable view - closing the "filter/sort has no saved view"
# gap against Notion's saved database views. Personal only: no sharing.
class KbSavedSearchesController < ApplicationController
  include RedmineKnowledgeBase::Authorization

  before_action :require_login
  before_action :authorize_view

  def create
    saved = KbSavedSearch.new(user: User.current, name: params[:name].presence || l(:label_kb_untitled_search))
    saved.params_hash = params.permit(:q, category_ids: [], tag_ids: [], status: []).to_h
    if saved.save
      flash[:notice] = l(:notice_kb_search_saved)
    else
      flash[:error] = saved.errors.full_messages.join(', ')
    end
    redirect_back fallback_location: knowledge_base_path
  end

  def destroy
    KbSavedSearch.where(user: User.current, id: params[:id]).destroy_all
    redirect_back fallback_location: knowledge_base_path
  end

  private

  def authorize_view
    render_403 unless User.current.allowed_to?(:view_knowledge_base, nil, global: true)
  end
end
