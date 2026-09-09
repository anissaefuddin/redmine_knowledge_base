# frozen_string_literal: true

class KbTag < ApplicationRecord
  has_many :kb_article_tags, dependent: :restrict_with_error
  has_many :kb_articles, through: :kb_article_tags

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }

  scope :sorted, -> { order(:position, :name) }
end
