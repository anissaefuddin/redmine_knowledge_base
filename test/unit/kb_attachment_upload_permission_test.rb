# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Regression test for the P0 finding: image/file upload in the article
# editor returned a generic 403 for any user whose only permissions were
# KB-specific. The original fix added attachments:upload to the action
# maps, but the plugin no longer uses core's /uploads endpoint at all (see
# KbUploadsController's comment on why: that endpoint can't be both
# session-authenticated and return JSON in one request) - it has its own
# /kb_uploads endpoint instead, gated by kb_uploads:create on the same
# three permissions. This asserts the fix still holds against that
# endpoint.
class KbAttachmentUploadPermissionTest < ActiveSupport::TestCase
  %i[add_kb_articles edit_own_kb_articles manage_kb_articles].each do |permission_name|
    define_method("test_#{permission_name}_grants_kb_upload") do
      permission = Redmine::AccessControl.permission(permission_name)
      assert_includes permission.actions, 'kb_uploads/create'
    end
  end

  def test_kb_only_role_can_actually_upload_via_kb_uploads
    role = Role.generate!(permissions: %i[view_knowledge_base add_kb_articles])
    user = User.generate!
    User.add_to_project(user, Project.find(1), role)

    assert user.allowed_to?({ controller: 'kb_uploads', action: 'create' }, nil, global: true)
  end
end
