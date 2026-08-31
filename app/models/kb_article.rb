# frozen_string_literal: true

class KbArticle < ApplicationRecord
  belongs_to :kb_category
  belongs_to :author, class_name: 'User'
  belongs_to :updated_by, class_name: 'User', optional: true

  has_many :kb_article_versions, -> { order(version: :desc) }, dependent: :destroy
  has_many :kb_article_projects, dependent: :destroy
  has_many :projects, through: :kb_article_projects

  # acts_as_attachable's default attachments_visible?/editable?/deletable? call
  # user.allowed_to?(permission, self.project) - that check only works for
  # project-scoped containers. KbArticle is deliberately global (no #project),
  # so those three are overridden below to route through our own visibility
  # model instead of silently returning false for everyone, admins included.
  acts_as_attachable

  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true

  before_create :init_version
  before_update :snapshot_version, if: -> { title_changed? || content_changed? }

  def visible?(user = User.current)
    kb_category.visible?(user)
  end

  def editable_by?(user = User.current)
    user.admin?
  end

  def attachments_visible?(user = User.current)
    visible?(user)
  end

  def attachments_editable?(user = User.current)
    editable_by?(user)
  end

  def attachments_deletable?(user = User.current)
    editable_by?(user)
  end

  private

  def init_version
    self.version = 1
  end

  # Snapshots the state being overwritten into kb_article_versions before the
  # update lands, attributed to whoever last touched it (or the original
  # author, on the article's very first edit).
  def snapshot_version
    kb_article_versions.create!(
      title: title_was,
      content: content_was,
      version: version,
      author_id: updated_by_id || author_id,
      created_at: Time.current
    )
    self.version += 1
  end
end
