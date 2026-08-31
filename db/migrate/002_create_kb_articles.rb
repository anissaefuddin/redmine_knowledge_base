# frozen_string_literal: true

class CreateKbArticles < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_articles do |t|
      t.references :kb_category, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content
      t.integer :author_id, null: false
      t.integer :updated_by_id
      t.integer :version, null: false, default: 1
      t.timestamps
    end

    add_index :kb_articles, :title
    add_foreign_key :kb_articles, :users, column: :author_id
    add_foreign_key :kb_articles, :users, column: :updated_by_id
  end
end
