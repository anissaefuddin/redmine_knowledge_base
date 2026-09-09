# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Covers finding #21 (search redesign) and #1/#31 (landing page redesign):
# global search now matches title/content/category/tags with category+tag+
# status filters, and the landing page renders Recently Updated/Popular/
# Category cards/Pinned sections without a q param.
class KnowledgeBaseControllerSearchTest < ActionController::TestCase
  tests KnowledgeBaseController

  def setup
    @project = Project.find(1)
    @viewer = User.generate!
    kb_role_for(@viewer)
    @editor = User.generate!
    kb_role_for(@editor, :manage_kb_articles)

    @hr_category = KbCategory.create!(name: 'HR Policies')
    @pmo_category = KbCategory.create!(name: 'PMO')
    @risk_tag = KbTag.create!(name: 'Risiko')

    @published = KbArticle.create!(title: 'Cuti Tahunan', content: 'Kebijakan cuti tahunan karyawan',
                                    kb_category: @hr_category, author: @editor, status: 'published',
                                    views_count: 10)
    @published.tags << @risk_tag

    @draft = KbArticle.create!(title: 'Draft internal', content: 'Belum siap publish',
                                kb_category: @pmo_category, author: @editor, status: 'draft')
  end

  def test_landing_page_renders_without_query
    kb_login_as(@viewer)
    compatible_request :get, :index
    assert_response :success
    assert_includes assigns(:recent_articles), @published
    refute_includes assigns(:recent_articles), @draft
  end

  def test_search_matches_content_not_just_title
    kb_login_as(@viewer)
    compatible_request :get, :index, q: 'kebijakan cuti'
    assert_response :success
    assert_includes assigns(:articles), @published
  end

  def test_search_matches_category_name
    kb_login_as(@viewer)
    compatible_request :get, :index, q: 'hr policies'
    assert_response :success
    assert_includes assigns(:articles), @published
  end

  def test_search_matches_tag_name
    kb_login_as(@viewer)
    compatible_request :get, :index, q: 'risiko'
    assert_response :success
    assert_includes assigns(:articles), @published
  end

  def test_viewer_search_excludes_other_peoples_drafts
    kb_login_as(@viewer)
    compatible_request :get, :index, q: 'draft internal'
    assert_response :success
    assert_empty assigns(:articles)
  end

  def test_editor_can_filter_search_by_status
    kb_login_as(@editor)
    compatible_request :get, :index, status: ['draft']
    assert_response :success
    assert_includes assigns(:articles), @draft
    refute_includes assigns(:articles), @published
  end

  def test_category_filter_narrows_results
    kb_login_as(@editor)
    compatible_request :get, :index, category_ids: [@pmo_category.id]
    assert_response :success
    assert_includes assigns(:articles), @draft
    refute_includes assigns(:articles), @published
  end
end
