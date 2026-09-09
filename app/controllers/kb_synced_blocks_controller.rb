# frozen_string_literal: true

# A tiny standalone editing page for one KbSyncedBlock, reached via the
# "Edit synced content" link on a synced block in the article editor (see
# kb_block_editor.js#buildSyncedRow) or directly by URL/slug. Its content is
# what {{kb_synced(slug)}} substitutes in wherever that slug is referenced -
# see lib/redmine_knowledge_base/macros.rb.
class KbSyncedBlocksController < ApplicationController
  include RedmineKnowledgeBase::Authorization

  before_action :require_login
  before_action :authorize_view, only: :show
  before_action :require_kb_can_upload, only: :update
  before_action :find_or_initialize_block

  def show; end

  def update
    if @block.update(content: params[:kb_synced_block][:content])
      flash[:notice] = l(:notice_successful_update)
      redirect_to kb_synced_block_path(@block.slug)
    else
      render :show
    end
  end

  private

  def find_or_initialize_block
    @slug = params[:id].to_s
    @block = KbSyncedBlock.find_or_initialize_by(slug: @slug)
  end

  def authorize_view
    render_403 unless User.current.allowed_to?(:view_knowledge_base, nil, global: true)
  end
end
