# frozen_string_literal: true

# A KB-owned upload endpoint, deliberately NOT reusing core's
# AttachmentsController#upload/:upload. That action's JSON response
# (format.api) requires the request to be recognized as JSON - but
# ApplicationController#find_current_user treats any request whose
# params[:format] is "json"/"xml" as an API request and skips session-
# cookie auth entirely (see api_request?), falling back to querying an API
# key that a browser upload never sends. There's no way to get both a
# session-authenticated request AND a core JSON response out of that one
# action. This controller sidesteps the conflict: it's a plain action that
# always renders JSON itself (no respond_to/format branching), so it never
# needs params[:format] set and normal session auth just works.
class KbUploadsController < ApplicationController
  include RedmineKnowledgeBase::Authorization

  before_action :require_login
  before_action :require_kb_can_upload

  def create
    unless request.media_type == 'application/octet-stream'
      head :not_acceptable
      return
    end

    attachment = Attachment.new(file: raw_request_body)
    attachment.author = User.current
    attachment.filename = params[:filename].presence || Redmine::Utils.random_hex(16)
    attachment.content_type = params[:content_type].presence

    if attachment.save
      render json: { upload: { id: attachment.id, token: attachment.token } }, status: :created
    else
      render json: { errors: attachment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Same approach as AttachmentsController#raw_request_body - avoids
  # reading the whole upload into memory when the Rack body already
  # behaves like an IO.
  def raw_request_body
    request.body.respond_to?(:size) ? request.body : request.raw_post
  end
end
