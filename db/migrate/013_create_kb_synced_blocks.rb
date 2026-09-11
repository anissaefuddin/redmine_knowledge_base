# frozen_string_literal: true

class CreateKbSyncedBlocks < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_synced_blocks do |t|
      t.string :slug, null: false
      # No `default:` here - MySQL rejects a DEFAULT on TEXT/BLOB/JSON
      # columns outright (Postgres allows it, which is why this went
      # unnoticed). Not load-bearing anyway: KbSyncedBlock already validates
      # `content` presence, so nothing can be saved without it being set in
      # Ruby first.
      t.text :content, null: false
      t.timestamps
    end
    add_index :kb_synced_blocks, :slug, unique: true
  end
end
