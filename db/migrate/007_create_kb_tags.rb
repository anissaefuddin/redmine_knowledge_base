# frozen_string_literal: true

class CreateKbTags < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_tags do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :kb_tags, :name, unique: true
  end
end
