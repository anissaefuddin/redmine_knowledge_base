# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# End-to-end (controller-level) coverage of the Viewer/Contributor/Editor/
# Admin permission matrix from finding #25/#27 of the KB UX review.
class KbArticlesControllerPermissionTest < ActionController::TestCase
  tests KbArticlesController

  def setup
    @project = Project.find(1)
    @category = KbCategory.create!(name: 'General')

    @viewer = User.generate!
    kb_role_for(@viewer)

    @author = User.generate!
    kb_role_for(@author, :add_kb_articles, :edit_own_kb_articles)

    @other_contributor = User.generate!
    kb_role_for(@other_contributor, :add_kb_articles, :edit_own_kb_articles)

    @editor = User.generate!
    kb_role_for(@editor, :manage_kb_articles)

    @article = KbArticle.create!(title: 'Original', content: 'Body', kb_category: @category,
                                  author: @author, status: 'draft')
  end

  def test_viewer_cannot_create_article
    kb_login_as(@viewer)
    compatible_request :get, :new, kb_category_id: @category.id
    assert_response :forbidden
  end

  def test_contributor_can_create_article
    kb_login_as(@author)
    compatible_request :get, :new, kb_category_id: @category.id
    assert_response :success
  end

  def test_contributor_can_edit_own_article
    kb_login_as(@author)
    compatible_request :get, :edit, id: @article.id
    assert_response :success
  end

  def test_contributor_cannot_edit_someone_elses_article
    kb_login_as(@other_contributor)
    compatible_request :get, :edit, id: @article.id
    assert_response :forbidden
  end

  def test_contributor_cannot_delete_any_article
    kb_login_as(@author)
    compatible_request :delete, :destroy, id: @article.id
    assert_response :forbidden
  end

  def test_contributor_cannot_pin_article
    kb_login_as(@author)
    compatible_request :post, :toggle_pin, id: @article.id
    assert_response :forbidden
  end

  def test_editor_can_edit_any_article
    kb_login_as(@editor)
    compatible_request :get, :edit, id: @article.id
    assert_response :success
  end

  def test_editor_can_delete_any_article
    kb_login_as(@editor)
    assert_difference('KbArticle.count', -1) do
      compatible_request :delete, :destroy, id: @article.id
    end
  end

  def test_viewer_cannot_see_someone_elses_draft
    kb_login_as(@viewer)
    compatible_request :get, :show, id: @article.id
    assert_response :forbidden
  end

  def test_author_can_see_own_draft
    kb_login_as(@author)
    compatible_request :get, :show, id: @article.id
    assert_response :success
  end
end
