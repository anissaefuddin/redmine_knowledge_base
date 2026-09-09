# frozen_string_literal: true

class AddIconToKbArticles < ActiveRecord::Migration[6.1]
  def change
    add_column :kb_articles, :icon, :string
  end
end
