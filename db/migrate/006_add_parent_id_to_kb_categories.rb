# frozen_string_literal: true

class AddParentIdToKbCategories < ActiveRecord::Migration[6.1]
  def change
    add_reference :kb_categories, :parent, foreign_key: { to_table: :kb_categories }, null: true
  end
end
