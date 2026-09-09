# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Covers finding #6 (tag management scaling): search, sorting, and an
# accurate per-tag article count that still paginates correctly (the
# correlated-subquery approach in KbTagsController#index, rather than a
# GROUP BY, is what keeps scope.count a plain integer for the paginator).
class KbTagsControllerIndexTest < ActionController::TestCase
  tests KbTagsController

  def setup
    @project = Project.find(1)
    @admin_role = Role.generate!(name: 'KB Admin', permissions: %i[view_knowledge_base manage_kb_tags])
    @admin_user = User.generate!
    User.add_to_project(@admin_user, @project, @admin_role)

    @category = KbCategory.create!(name: 'General')
    @author = User.generate!

    @popular_tag = KbTag.create!(name: 'Kebijakan')
    @rare_tag = KbTag.create!(name: 'Metodologi')

    2.times do |i|
      article = KbArticle.create!(title: "Article #{i}", content: 'Body', kb_category: @category,
                                   author: @author, status: 'published')
      article.tags << @popular_tag
    end
  end

  def test_index_reports_correct_article_count_per_tag
    kb_login_as(@admin_user)
    compatible_request :get, :index
    assert_response :success
    tags = assigns(:tags).index_by(&:id)
    assert_equal 2, tags[@popular_tag.id].articles_count.to_i
    assert_equal 0, tags[@rare_tag.id].articles_count.to_i
  end

  def test_search_filters_by_name
    kb_login_as(@admin_user)
    compatible_request :get, :index, q: 'kebijakan'
    assert_response :success
    assert_equal [@popular_tag.id], assigns(:tags).map(&:id)
  end

  def test_sort_by_articles_count_descending
    kb_login_as(@admin_user)
    compatible_request :get, :index, sort: 'articles:desc'
    assert_response :success
    assert_equal @popular_tag.id, assigns(:tags).first.id
  end
end
