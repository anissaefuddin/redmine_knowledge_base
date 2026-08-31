# frozen_string_literal: true

class CreateKbCategories < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_categories do |t|
      t.string :name, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :kb_categories, :name, unique: true
  end
end
