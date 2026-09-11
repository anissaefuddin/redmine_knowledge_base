# frozen_string_literal: true

class CreateKbSavedSearches < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_saved_searches do |t|
      t.integer :user_id, null: false
      t.string :name, null: false
      # No `default:` - MySQL rejects a DEFAULT on TEXT/BLOB/JSON columns
      # (see the same note in 013_create_kb_synced_blocks.rb). Not
      # load-bearing: KbSavedSearch validates `params` presence, and
      # #params_hash= always serializes a real value before save.
      t.text :params, null: false
      t.timestamps
    end
    add_index :kb_saved_searches, :user_id
  end
end
