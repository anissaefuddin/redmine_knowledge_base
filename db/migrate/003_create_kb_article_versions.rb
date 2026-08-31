# frozen_string_literal: true

# Audit trail: one immutable row per superseded revision of a KbArticle.
# The current text lives directly on kb_articles; this table only ever
# receives inserts (never updated), mirroring how Redmine keeps wiki history.
class CreateKbArticleVersions < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_article_versions do |t|
      t.references :kb_article, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content
      t.integer :version, null: false
      t.integer :author_id, null: false
      t.datetime :created_at, null: false
    end

    add_index :kb_article_versions, %i[kb_article_id version], unique: true, name: 'index_kb_article_versions_uniq'
    add_foreign_key :kb_article_versions, :users, column: :author_id
  end
end
