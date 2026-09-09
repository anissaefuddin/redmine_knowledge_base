# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Fills in E2E matrix coverage (finding #27, section E "Relations") for
# related-article and related-project linking, which had no test coverage.
class KbArticlesControllerRelationsTest < ActionController::TestCase
  tests KbArticlesController

  def setup
    @project = Project.find(1)
    @category = KbCategory.create!(name: 'General')
    @editor = User.generate!
    kb_role_for(@editor, :manage_kb_articles)

    @article = KbArticle.create!(title: 'Main', content: 'Body', kb_category: @category,
                                  author: @editor, status: 'published')
    @related = KbArticle.create!(title: 'Related', content: 'Body', kb_category: @category,
                                  author: @editor, status: 'published')
  end

  def test_add_related_article
    kb_login_as(@editor)
    compatible_request :post, :add_related, id: @article.id, related_id: @related.id
    assert_includes @article.reload.related_articles, @related
  end

  def test_remove_related_article
    @article.related_articles << @related
    kb_login_as(@editor)
    compatible_request :delete, :remove_related, id: @article.id, related_id: @related.id
    refute_includes @article.reload.related_articles, @related
  end

  def test_add_project_link
    kb_login_as(@editor)
    compatible_request :post, :add_project, id: @article.id, project_id: @project.id
    assert_includes @article.reload.projects, @project
  end

  def test_remove_project_link
    @article.projects << @project
    kb_login_as(@editor)
    compatible_request :delete, :remove_project, id: @article.id, project_id: @project.id
    refute_includes @article.reload.projects, @project
  end
end
