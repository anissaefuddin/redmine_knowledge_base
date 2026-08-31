# frozen_string_literal: true

class KbCategoryGroup < ApplicationRecord
  belongs_to :kb_category
  belongs_to :group

  validates :group_id, uniqueness: { scope: :kb_category_id }
end
