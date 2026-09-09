# frozen_string_literal: true

class AddStatusAndViewsToKbArticles < ActiveRecord::Migration[6.1]
  def up
    add_column :kb_articles, :status, :string, null: false, default: 'draft'
    add_column :kb_articles, :views_count, :integer, null: false, default: 0
    add_index :kb_articles, :status

    # Articles created before this migration predate the draft/published
    # concept - backfill them as published so they don't silently vanish
    # from the list for users who could already see them.
    execute "UPDATE kb_articles SET status = 'published'"
  end

  def down
    remove_index :kb_articles, :status
    remove_column :kb_articles, :views_count
    remove_column :kb_articles, :status
  end
end
