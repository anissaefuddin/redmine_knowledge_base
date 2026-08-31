# frozen_string_literal: true

# Reference-only link: records that an article's documentation has been
# implemented in a project. Purely a marker for traceability from the KB
# side - it does not affect the project itself and adds no UI there.
class CreateKbArticleProjects < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_article_projects do |t|
      t.references :kb_article, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end

    add_index :kb_article_projects, %i[kb_article_id project_id], unique: true, name: 'index_kb_article_projects_uniq'
  end
end
