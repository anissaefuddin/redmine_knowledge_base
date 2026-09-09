# frozen_string_literal: true

class AddDeletedAtToKbArticles < ActiveRecord::Migration[6.1]
  def change
    add_column :kb_articles, :deleted_at, :datetime
    add_index :kb_articles, :deleted_at
  end
end
