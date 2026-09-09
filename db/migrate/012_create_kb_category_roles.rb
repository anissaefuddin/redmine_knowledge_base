# frozen_string_literal: true

# Second, independent restriction axis alongside kb_category_groups: a
# category is visible to a user if they match ANY configured group OR ANY
# configured role (not both required) - see KbCategory#visible?.
class CreateKbCategoryRoles < ActiveRecord::Migration[6.1]
  def change
    create_table :kb_category_roles do |t|
      t.references :kb_category, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.timestamps
    end

    add_index :kb_category_roles, %i[kb_category_id role_id], unique: true, name: 'index_kb_category_roles_uniq'
  end
end
