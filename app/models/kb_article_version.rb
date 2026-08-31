# frozen_string_literal: true

# Immutable snapshot row - never updated after creation, see KbArticle#snapshot_version.
class KbArticleVersion < ApplicationRecord
  belongs_to :kb_article
  belongs_to :author, class_name: 'User'
end
