# frozen_string_literal: true

# The shared content behind a {{kb_synced(slug)}} macro reference (see
# lib/redmine_knowledge_base/macros.rb) - editing this once updates every
# article that embeds the same slug.
class KbSyncedBlock < ApplicationRecord
  validates :slug, presence: true, uniqueness: true,
                    format: { with: /\A[a-zA-Z0-9_-]+\z/, message: :kb_invalid_slug }
  validates :content, presence: true
end
