# frozen_string_literal: true

# Reference-only link: records that an article's documentation has been
# implemented in a project. Purely a marker for traceability from the KB
# side - it does not affect the project itself and adds no UI there.
class CreateKbArticleProjects < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_article_projects do |t|
      t.references :kb_article, null: false, foreign_key: true
      # Plain t.integer (not t.references) - Redmine's own `projects.id` is a
      # 4-byte `int` on MySQL installs, not the `bigint` t.references defaults
      # to; a type mismatch there breaks the FK constraint under MySQL (fine
      # on Postgres, which is why this went unnoticed). Match core Redmine's
      # column type explicitly instead of trusting the Rails default - see
      # how kb_articles.author_id/kb_category_groups.group_id already do this
      # for the same reason.
      t.integer :project_id, null: false
      t.datetime :created_at, null: false
    end

    add_foreign_key :kb_article_projects, :projects, column: :project_id
    add_index :kb_article_projects, %i[kb_article_id project_id], unique: true, name: 'index_kb_article_projects_uniq'
  end
end
