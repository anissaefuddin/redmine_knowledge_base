# frozen_string_literal: true

# One-directional "see also" link between two articles, curated by an admin
# in the editor (not derived from tags/category). Reverse direction is looked
# up via KbArticle#referenced_by for display, see KbArticle model.
class CreateKbArticleRelations < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_article_relations do |t|
      t.references :kb_article, null: false, foreign_key: true
      t.references :related_kb_article, null: false, foreign_key: { to_table: :kb_articles }
      t.timestamps
    end

    add_index :kb_article_relations, %i[kb_article_id related_kb_article_id], unique: true, name: 'index_kb_article_relations_uniq'
  end
end
