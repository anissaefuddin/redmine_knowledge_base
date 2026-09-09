# frozen_string_literal: true

class CreateKbSyncedBlocks < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_synced_blocks do |t|
      t.string :slug, null: false
      t.text :content, null: false, default: ''
      t.timestamps
    end
    add_index :kb_synced_blocks, :slug, unique: true
  end
end
