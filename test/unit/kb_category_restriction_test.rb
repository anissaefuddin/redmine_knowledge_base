# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Covers finding #26 from the KB UX review: role-restricted categories must
# be visible only to matching roles, and restriction must NOT be inherited
# by subcategories (each node's restriction is independent - see
# KbCategory#restricted?).
class KbCategoryRestrictionTest < ActiveSupport::TestCase
  def setup
    @project = Project.find(1)

    @hr_role = Role.generate!(name: 'HR Staff', permissions: [:view_knowledge_base])
    @pmo_role = Role.generate!(name: 'PMO Staff', permissions: [:view_knowledge_base])
    @no_kb_role = Role.generate!(name: 'No KB Access', permissions: [])

    @hr_user = User.generate!
    User.add_to_project(@hr_user, @project, @hr_role)

    @pmo_user = User.generate!
    User.add_to_project(@pmo_user, @project, @pmo_role)

    @no_kb_user = User.generate!
    User.add_to_project(@no_kb_user, @project, @no_kb_role)

    @admin = User.find(1)

    @hr_category = KbCategory.create!(name: 'HR')
    @hr_category.roles << @hr_role

    @hr_subcategory = KbCategory.create!(name: 'HR Recruitment', parent: @hr_category)
  end

  def test_restricted_category_visible_to_matching_role
    assert @hr_category.visible?(@hr_user)
  end

  def test_restricted_category_not_visible_to_other_role
    refute @hr_category.visible?(@pmo_user)
  end

  def test_restricted_category_not_visible_without_view_permission
    refute @hr_category.visible?(@no_kb_user)
  end

  def test_restricted_category_always_visible_to_admin
    assert @hr_category.visible?(@admin)
  end

  def test_unrestricted_category_visible_to_anyone_with_view_permission
    plain_category = KbCategory.create!(name: 'General')
    assert plain_category.visible?(@pmo_user)
  end

  # The behavior under test: restriction is explicit per-node, not
  # inherited. A subcategory of a restricted category starts out
  # unrestricted and must be restricted separately if that's wanted -
  # this is deliberate (see KbCategory#restricted? comment), verified here
  # so a future refactor can't silently start inheriting without a test
  # noticing.
  def test_restriction_is_not_inherited_by_subcategories
    refute @hr_subcategory.restricted?
    assert @hr_subcategory.visible?(@pmo_user)
    refute @hr_subcategory.visible?(@no_kb_user) # still needs view_knowledge_base itself
  end

  def test_subcategory_can_be_restricted_independently_of_parent
    @hr_subcategory.roles << @hr_role
    assert @hr_subcategory.restricted?
    assert @hr_subcategory.visible?(@hr_user)
    refute @hr_subcategory.visible?(@pmo_user)
  end

  def test_group_restriction_matches_independently_of_role_restriction
    group = Group.generate!
    group.users << @pmo_user
    @hr_category.groups << group

    # PMO user now matches on the group axis even though they still don't
    # hold the HR Staff role - group and role restrictions are OR'd.
    assert @hr_category.visible?(@pmo_user)
  end
end
