# frozen_string_literal: true

# Restriction join table: a KbCategory with zero rows here is visible to
# everyone with the view_knowledge_base permission (default-open, per design).
# Adding a row here narrows that category to members of the given Group only.
class CreateKbCategoryGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_category_groups do |t|
      t.references :kb_category, null: false, foreign_key: true
      t.integer :group_id, null: false
      t.datetime :created_at, null: false
    end

    add_index :kb_category_groups, %i[kb_category_id group_id], unique: true, name: 'index_kb_category_groups_uniq'
    add_foreign_key :kb_category_groups, :users, column: :group_id
  end
end
