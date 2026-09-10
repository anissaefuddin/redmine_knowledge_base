# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Covers finding #2: creating a tag inline from the article form, without
# needing manage_kb_tags (Admin-tier full tag administration stays separate).
class KbTagsControllerQuickCreateTest < ActionController::TestCase
  tests KbTagsController

  def setup
    @project = Project.find(1)
    @contributor = User.generate!
    kb_role_for(@contributor, :add_kb_articles)

    @viewer = User.generate!
    kb_role_for(@viewer)
  end

  def test_contributor_can_quick_create_a_tag
    kb_login_as(@contributor)
    assert_difference('KbTag.count', 1) do
      compatible_request :post, :quick_create, name: 'Onboarding'
    end
    assert_response :success
  end

  def test_viewer_without_edit_permission_cannot_quick_create
    kb_login_as(@viewer)
    assert_no_difference('KbTag.count') do
      compatible_request :post, :quick_create, name: 'Nope'
    end
    assert_response :forbidden
  end

  def test_blank_name_is_rejected
    kb_login_as(@contributor)
    compatible_request :post, :quick_create, name: ''
    assert_response :unprocessable_entity
  end
end
