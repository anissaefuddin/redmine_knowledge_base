# frozen_string_literal: true

class CreateKbSavedSearches < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_saved_searches do |t|
      t.integer :user_id, null: false
      t.string :name, null: false
      t.text :params, null: false, default: '{}'
      t.timestamps
    end
    add_index :kb_saved_searches, :user_id
  end
end
