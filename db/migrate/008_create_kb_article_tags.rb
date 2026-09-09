# frozen_string_literal: true

class CreateKbArticleTags < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_article_tags do |t|
      t.references :kb_article, null: false, foreign_key: true
      t.references :kb_tag, null: false, foreign_key: true
      t.timestamps
    end

    add_index :kb_article_tags, %i[kb_article_id kb_tag_id], unique: true, name: 'index_kb_article_tags_uniq'
  end
end
