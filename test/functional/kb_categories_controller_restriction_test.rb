# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# End-to-end (controller-level) coverage of finding #26: role-restricted
# categories, and that restriction is not inherited by subcategories.
class KbCategoriesControllerRestrictionTest < ActionController::TestCase
  tests KbCategoriesController

  def setup
    @project = Project.find(1)

    @hr_role = Role.generate!(name: 'HR Staff', permissions: [:view_knowledge_base])
    @pmo_role = Role.generate!(name: 'PMO Staff', permissions: [:view_knowledge_base])

    @hr_user = User.generate!
    User.add_to_project(@hr_user, @project, @hr_role)

    @pmo_user = User.generate!
    User.add_to_project(@pmo_user, @project, @pmo_role)

    @hr_category = KbCategory.create!(name: 'HR')
    @hr_category.roles << @hr_role

    @hr_subcategory = KbCategory.create!(name: 'HR Recruitment', parent: @hr_category)
  end

  def test_hr_staff_can_view_hr_category
    kb_login_as(@hr_user)
    compatible_request :get, :show, id: @hr_category.id
    assert_response :success
  end

  def test_pmo_staff_cannot_view_hr_category
    kb_login_as(@pmo_user)
    compatible_request :get, :show, id: @hr_category.id
    assert_response :forbidden
  end

  # Restriction is per-node, not inherited: the HR subcategory has no
  # restriction of its own, so anyone with view_knowledge_base can browse
  # it even though its parent is restricted to HR Staff.
  def test_unrestricted_subcategory_of_restricted_parent_is_visible_to_others
    kb_login_as(@pmo_user)
    compatible_request :get, :show, id: @hr_subcategory.id
    assert_response :success
  end
end
