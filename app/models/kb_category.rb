# frozen_string_literal: true

class KbCategory < ApplicationRecord
  has_many :kb_articles, -> { order(:title) }, dependent: :restrict_with_error
  has_many :kb_category_groups, dependent: :destroy
  has_many :groups, through: :kb_category_groups

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }

  scope :sorted, -> { order(:position, :name) }

  # Opt-in restriction: a category with no groups attached is unrestricted.
  def restricted?
    kb_category_groups.exists?
  end

  def visible?(user = User.current)
    return true if user.admin?
    return false unless user.allowed_to?(:view_knowledge_base, nil, global: true)
    return true unless restricted?

    (user.groups.pluck(:id) & group_ids).any?
  end
end
