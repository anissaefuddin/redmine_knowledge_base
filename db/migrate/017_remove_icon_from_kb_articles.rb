# frozen_string_literal: true

# Reverts 014_add_icon_to_kb_articles - the feature was pulled after
# shipping (no UI ended up wanting it after all).
class RemoveIconFromKbArticles < ActiveRecord::Migration[6.1]
  def change
    remove_column :kb_articles, :icon, :string
  end
end
