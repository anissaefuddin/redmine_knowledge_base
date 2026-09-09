# frozen_string_literal: true

class KbArticleRelation < ApplicationRecord
  belongs_to :kb_article
  belongs_to :related_kb_article, class_name: 'KbArticle'

  validates :related_kb_article_id, uniqueness: { scope: :kb_article_id }
  validate :not_self_referential

  private

  def not_self_referential
    errors.add(:related_kb_article_id, :invalid) if kb_article_id.present? && kb_article_id == related_kb_article_id
  end
end
