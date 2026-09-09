# frozen_string_literal: true

class KbCategoryRole < ApplicationRecord
  belongs_to :kb_category
  belongs_to :role

  validates :role_id, uniqueness: { scope: :kb_category_id }
end
