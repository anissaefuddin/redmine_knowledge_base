# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Fills in E2E matrix coverage (finding #27, section A "Setup") for tag
# create/update/destroy, complementing the P2 index/search/sort tests.
class KbTagsControllerCrudTest < ActionController::TestCase
  tests KbTagsController

  def setup
    @project = Project.find(1)
    @admin_user = User.generate!
    kb_role_for(@admin_user, :manage_kb_tags)

    @viewer = User.generate!
    kb_role_for(@viewer)

    @category = KbCategory.create!(name: 'General')
    @author = User.generate!
    @tag = KbTag.create!(name: 'Kebijakan')
  end

  def test_viewer_cannot_manage_tags
    kb_login_as(@viewer)
    compatible_request :get, :new
    assert_response :forbidden
  end

  def test_admin_can_create_tag
    kb_login_as(@admin_user)
    assert_difference('KbTag.count', 1) do
      compatible_request :post, :create, kb_tag: { name: 'Risiko' }
    end
  end

  def test_admin_can_rename_tag
    kb_login_as(@admin_user)
    compatible_request :put, :update, id: @tag.id, kb_tag: { name: 'Kebijakan Baru' }
    assert_equal 'Kebijakan Baru', @tag.reload.name
  end

  def test_cannot_destroy_tag_still_used_by_an_article
    article = KbArticle.create!(title: 'Doc', content: 'Body', kb_category: @category,
                                 author: @author, status: 'published')
    article.tags << @tag
    kb_login_as(@admin_user)
    assert_no_difference('KbTag.count') do
      compatible_request :delete, :destroy, id: @tag.id
    end
  end

  def test_destroy_unused_tag_succeeds
    kb_login_as(@admin_user)
    assert_difference('KbTag.count', -1) do
      compatible_request :delete, :destroy, id: @tag.id
    end
  end
end
