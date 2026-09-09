# frozen_string_literal: true

class KbArticleTag < ApplicationRecord
  belongs_to :kb_article
  belongs_to :kb_tag

  validates :kb_tag_id, uniqueness: { scope: :kb_article_id }
end
