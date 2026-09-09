# frozen_string_literal: true

# A named, reusable set of search filters (category/tag/status/sort) - the
# "save this as a view" gap identified against Notion's saved database
# views. Scoped to the user who created it; there's no sharing concept yet.
# `params` stores its filter hash as a plain JSON string in a text column
# (via #params_hash) rather than ActiveRecord's `serialize`, to sidestep
# that API's signature churn across Rails versions.
class KbSavedSearch < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, length: { maximum: 255 }
  validates :params, presence: true

  scope :sorted, -> { order(:name) }

  def params_hash
    JSON.parse(params.presence || '{}')
  rescue JSON::ParserError
    {}
  end

  def params_hash=(hash)
    self.params = hash.to_json
  end
end
