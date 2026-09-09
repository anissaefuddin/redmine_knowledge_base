# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Covers the Trash/Restore gap from the Notion parity audit: Delete should
# be recoverable, not an immediate hard delete.
class KbArticlesControllerTrashTest < ActionController::TestCase
  tests KbArticlesController

  def setup
    @project = Project.find(1)
    @category = KbCategory.create!(name: 'General')
    @editor = User.generate!
    kb_role_for(@editor, :manage_kb_articles)

    @viewer = User.generate!
    kb_role_for(@viewer)

    @article = KbArticle.create!(title: 'Doc', content: 'Body', kb_category: @category,
                                  author: @editor, status: 'published')
  end

  def test_destroy_soft_deletes_instead_of_removing_the_row
    kb_login_as(@editor)
    assert_no_difference('KbArticle.unscoped.count') do
      compatible_request :delete, :destroy, id: @article.id
    end
    assert @article.reload.deleted_at.present?
  end

  def test_trashed_article_is_invisible_to_normal_queries
    @article.soft_delete!
    refute KbArticle.exists?(@article.id)
    assert KbArticle.unscoped.exists?(@article.id)
  end

  def test_trashed_article_returns_404_on_show
    @article.soft_delete!
    kb_login_as(@editor)
    compatible_request :get, :show, id: @article.id
    assert_response :not_found
  end

  def test_viewer_cannot_see_trash_list
    kb_login_as(@viewer)
    compatible_request :get, :trash
    assert_response :forbidden
  end

  def test_editor_can_list_and_restore_from_trash
    @article.soft_delete!
    kb_login_as(@editor)
    compatible_request :get, :trash
    assert_response :success
    assert_includes assigns(:articles), @article

    compatible_request :post, :restore, id: @article.id
    assert_nil @article.reload.deleted_at
  end

  def test_destroy_permanently_removes_the_row
    @article.soft_delete!
    kb_login_as(@editor)
    assert_difference('KbArticle.unscoped.count', -1) do
      compatible_request :delete, :destroy_permanently, id: @article.id
    end
  end
end
