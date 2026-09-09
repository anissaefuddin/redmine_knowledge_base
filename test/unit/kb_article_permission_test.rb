# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Covers finding #25 from the KB UX review: the Viewer/Contributor/Editor/
# Admin permission matrix, specifically the "Edit own article" vs "Edit all
# articles" distinction that KbArticle#visible?/#editable_by? implement.
class KbArticlePermissionTest < ActiveSupport::TestCase
  def setup
    @project = Project.find(1)
    @category = KbCategory.create!(name: 'General')

    @viewer_role = Role.generate!(name: 'KB Viewer', permissions: [:view_knowledge_base])
    @contributor_role = Role.generate!(name: 'KB Contributor',
                                        permissions: %i[view_knowledge_base add_kb_articles edit_own_kb_articles])
    @editor_role = Role.generate!(name: 'KB Editor', permissions: %i[view_knowledge_base manage_kb_articles])

    @viewer = User.generate!
    User.add_to_project(@viewer, @project, @viewer_role)

    @author = User.generate!
    User.add_to_project(@author, @project, @contributor_role)

    @other_contributor = User.generate!
    User.add_to_project(@other_contributor, @project, @contributor_role)

    @editor = User.generate!
    User.add_to_project(@editor, @project, @editor_role)

    @admin = User.find(1)

    @draft = KbArticle.create!(title: 'Draft article', content: 'Body', kb_category: @category,
                                author: @author, status: 'draft')
    @published = KbArticle.create!(title: 'Published article', content: 'Body', kb_category: @category,
                                    author: @author, status: 'published')
  end

  # --- visibility ---

  def test_draft_visible_to_its_author
    assert @draft.visible?(@author)
  end

  def test_draft_not_visible_to_a_plain_viewer
    refute @draft.visible?(@viewer)
  end

  def test_draft_not_visible_to_another_contributor
    refute @draft.visible?(@other_contributor)
  end

  def test_draft_visible_to_an_editor
    assert @draft.visible?(@editor)
  end

  def test_draft_visible_to_admin
    assert @draft.visible?(@admin)
  end

  def test_published_visible_to_a_plain_viewer
    assert @published.visible?(@viewer)
  end

  # --- editability ---

  def test_author_can_edit_own_article
    assert @draft.editable_by?(@author)
  end

  def test_contributor_cannot_edit_someone_elses_article
    refute @draft.editable_by?(@other_contributor)
  end

  def test_viewer_cannot_edit_any_article
    refute @published.editable_by?(@viewer)
  end

  def test_editor_can_edit_any_article
    assert @draft.editable_by?(@editor)
    assert @published.editable_by?(@editor)
  end
end
