# frozen_string_literal: true

class KbArticle < ApplicationRecord
  belongs_to :kb_category
  belongs_to :author, class_name: 'User'
  belongs_to :updated_by, class_name: 'User', optional: true

  has_many :kb_article_versions, -> { order(version: :desc) }, dependent: :destroy
  has_many :kb_article_projects, dependent: :destroy
  has_many :projects, through: :kb_article_projects

  has_many :kb_article_tags, dependent: :destroy
  has_many :tags, through: :kb_article_tags, source: :kb_tag

  # "See also" links this article points at. The reverse direction (who
  # else points at this article) is looked up on demand via #referenced_by
  # for display, but still needs its own dependent: :destroy below -
  # otherwise deleting an article that other articles reference would hit
  # the related_kb_article_id foreign key instead of cleaning up.
  has_many :kb_article_relations, dependent: :destroy
  has_many :related_articles, through: :kb_article_relations, source: :related_kb_article
  has_many :inverse_kb_article_relations, class_name: 'KbArticleRelation',
                                           foreign_key: :related_kb_article_id, dependent: :destroy

  enum status: { draft: 'draft', published: 'published' }

  scope :pinned, -> { where.not(pinned_at: nil).order(pinned_at: :desc) }

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
    return true if user.admin?
    return false unless published?

    kb_category.visible?(user)
  end

  def referenced_by
    KbArticle.joins(:kb_article_relations).where(kb_article_relations: { related_kb_article_id: id })
  end

  def pinned?
    pinned_at.present?
  end

  def editable_by?(user = User.current)
    user.allowed_to?(:manage_kb_articles, nil, global: true)
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
