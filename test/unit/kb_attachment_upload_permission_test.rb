# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Regression test for the P0 finding: image/file upload in the article
# editor returned a generic 403 for any user whose only permissions were
# KB-specific (no other project permission like add_issues/edit_wiki_pages
# happened to also grant attachments/upload). Root cause was
# manage_kb_articles's action map not listing attachments:upload - fixed in
# init.rb. This asserts the fix at both the permission-definition level and
# the actual User#allowed_to? check the core /uploads.json endpoint uses.
class KbAttachmentUploadPermissionTest < ActiveSupport::TestCase
  %i[add_kb_articles edit_own_kb_articles manage_kb_articles].each do |permission_name|
    define_method("test_#{permission_name}_grants_attachment_upload") do
      permission = Redmine::AccessControl.permission(permission_name)
      assert_includes permission.actions, 'attachments/upload'
    end
  end

  def test_kb_only_role_can_actually_upload_attachments
    role = Role.generate!(permissions: %i[view_knowledge_base add_kb_articles])
    user = User.generate!
    User.add_to_project(user, Project.find(1), role)

    assert user.allowed_to?({ controller: 'attachments', action: 'upload' }, nil, global: true)
  end
end
