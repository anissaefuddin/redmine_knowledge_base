# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Fills in E2E matrix coverage (finding #27, section A "Setup") that wasn't
# exercised by the P1 restriction tests: category/subcategory create/update/
# destroy, and the group/role restriction being saved from the form.
class KbCategoriesControllerCrudTest < ActionController::TestCase
  tests KbCategoriesController

  def setup
    @project = Project.find(1)
    @admin_user = User.generate!
    kb_role_for(@admin_user, :manage_kb_categories)

    @viewer = User.generate!
    kb_role_for(@viewer)

    @parent = KbCategory.create!(name: 'PMO')
  end

  def test_viewer_cannot_manage_categories
    kb_login_as(@viewer)
    compatible_request :get, :new
    assert_response :forbidden
  end

  def test_admin_can_create_subcategory
    kb_login_as(@admin_user)
    assert_difference('KbCategory.count', 1) do
      compatible_request :post, :create, kb_category: { name: 'Project Charter', parent_id: @parent.id }
    end
    subcategory = KbCategory.order(:id).last
    assert_equal @parent, subcategory.parent
  end

  def test_admin_can_restrict_category_via_role_ids
    role = Role.generate!(name: 'HR Staff', permissions: [:view_knowledge_base])
    kb_login_as(@admin_user)
    compatible_request :put, :update, id: @parent.id,
                        kb_category: { name: @parent.name }, role_ids: [role.id]
    @parent.reload
    assert @parent.restricted?
    assert_equal [role.id], @parent.role_ids
  end

  def test_cannot_destroy_category_with_articles
    author = User.generate!
    KbArticle.create!(title: 'Doc', content: 'Body', kb_category: @parent, author: author, status: 'published')
    kb_login_as(@admin_user)
    assert_no_difference('KbCategory.count') do
      compatible_request :delete, :destroy, id: @parent.id
    end
  end

  def test_cannot_destroy_category_with_subcategories
    KbCategory.create!(name: 'Child', parent: @parent)
    kb_login_as(@admin_user)
    assert_no_difference('KbCategory.count') do
      compatible_request :delete, :destroy, id: @parent.id
    end
  end

  def test_destroy_empty_category_succeeds
    kb_login_as(@admin_user)
    assert_difference('KbCategory.count', -1) do
      compatible_request :delete, :destroy, id: @parent.id
    end
  end
end
