# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Covers finding #18 (article versioning UI - Duplicate action, Compare/diff
# view) from the KB UX review.
class KbArticlesControllerP3Test < ActionController::TestCase
  tests KbArticlesController

  def setup
    @project = Project.find(1)
    @category = KbCategory.create!(name: 'General')

    @viewer = User.generate!
    kb_role_for(@viewer)

    @contributor = User.generate!
    kb_role_for(@contributor, :add_kb_articles, :edit_own_kb_articles)

    @editor = User.generate!
    kb_role_for(@editor, :manage_kb_articles)

    @tag = KbTag.create!(name: 'SOP')
    @article = KbArticle.create!(title: 'Original Title', content: 'v1 content', kb_category: @category,
                                  author: @editor, status: 'published')
    @article.tags << @tag
    @article.update!(updated_by: @editor, content: 'v2 content')
  end

  def test_viewer_cannot_duplicate
    kb_login_as(@viewer)
    compatible_request :post, :duplicate, id: @article.id
    assert_response :forbidden
  end

  def test_contributor_can_duplicate_into_own_draft
    kb_login_as(@contributor)
    assert_difference('KbArticle.count', 1) do
      compatible_request :post, :duplicate, id: @article.id
    end
    copy = KbArticle.order(:id).last
    assert_equal "Copy of #{@article.title}", copy.title
    assert_equal @contributor, copy.author
    assert copy.draft?
    assert_equal [@tag.id], copy.tag_ids
    assert_redirected_to edit_kb_article_path(copy)
  end

  def test_duplicate_does_not_copy_pin_or_view_count
    @article.update_column(:pinned_at, Time.current)
    @article.update_column(:views_count, 42)
    kb_login_as(@contributor)
    compatible_request :post, :duplicate, id: @article.id
    copy = KbArticle.order(:id).last
    refute copy.pinned?
    assert_equal 0, copy.views_count
  end

  def test_diff_shows_changes_between_version_and_current
    kb_login_as(@viewer)
    compatible_request :get, :diff, id: @article.id, version: 1
    assert_response :success
    assert_equal 1, assigns(:version).version
  end
end
