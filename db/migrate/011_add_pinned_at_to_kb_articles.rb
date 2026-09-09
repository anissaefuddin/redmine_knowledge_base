# frozen_string_literal: true

# nil = not pinned; a timestamp = pinned since that moment (also used to
# order pinned articles, newest pin first), see KbArticle.pinned scope.
class AddPinnedAtToKbArticles < ActiveRecord::Migration[6.1]
  def change
    add_column :kb_articles, :pinned_at, :datetime, null: true
    add_index :kb_articles, :pinned_at
  end
end
