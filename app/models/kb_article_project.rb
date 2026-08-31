# frozen_string_literal: true

# Reference-only marker: "this article's documentation is already implemented
# in this project." No status/date field by design (v1 scope) - presence of
# the row is the entire signal.
class KbArticleProject < ApplicationRecord
  belongs_to :kb_article
  belongs_to :project

  validates :project_id, uniqueness: { scope: :kb_article_id }
end
