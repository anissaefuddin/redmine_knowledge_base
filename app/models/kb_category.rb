# frozen_string_literal: true

class KbCategory < ApplicationRecord
  belongs_to :parent, class_name: 'KbCategory', optional: true
  has_many :children, -> { sorted }, class_name: 'KbCategory', foreign_key: :parent_id,
                                      inverse_of: :parent, dependent: :restrict_with_error
  has_many :kb_articles, -> { order(:title) }, dependent: :restrict_with_error
  has_many :kb_category_groups, dependent: :destroy
  has_many :groups, through: :kb_category_groups

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }

  scope :sorted, -> { order(:position, :name) }
  scope :roots, -> { where(parent_id: nil) }

  # Populated only by .build_tree below - holds already-loaded children so
  # rendering a tree never re-queries per node. The real #children
  # association above is still used anywhere a fresh query is wanted (e.g.
  # the dependent: :restrict_with_error check on destroy).
  attr_accessor :loaded_children

  # Builds the full category tree in memory from a flat, already-loaded
  # list (one query total) instead of walking the #children association
  # node by node.
  def self.build_tree(categories = KbCategory.sorted.to_a)
    by_parent = categories.group_by(&:parent_id)
    attach = lambda do |nodes|
      nodes.each do |node|
        node.loaded_children = by_parent[node.id] || []
        attach.call(node.loaded_children)
      end
    end
    roots = by_parent[nil] || []
    attach.call(roots)
    roots
  end

  # Opt-in restriction: a category with no groups attached is unrestricted.
  # Deliberately not inherited from the parent category - each node's
  # restriction is independent, matching the pre-hierarchy behavior.
  def restricted?
    kb_category_groups.exists?
  end

  def visible?(user = User.current)
    return true if user.admin?
    return false unless user.allowed_to?(:view_knowledge_base, nil, global: true)
    return true unless restricted?

    (user.groups.pluck(:id) & group_ids).any?
  end

  def ancestors
    parent ? parent.ancestors + [parent] : []
  end

  def self_and_ancestors
    ancestors + [self]
  end

  # Uses loaded_children (from .build_tree) when present to avoid queries;
  # falls back to the real association otherwise.
  def descendants
    (loaded_children || children).flat_map { |c| [c] + c.descendants }
  end

  def self_and_descendants
    [self] + descendants
  end

  # Article count including this category and all its descendants. Pass a
  # precomputed KbArticle.group(:kb_category_id).count hash when rendering
  # a whole tree to avoid recomputing it per node.
  def article_count(counts_by_category_id = nil)
    counts = counts_by_category_id || KbArticle.group(:kb_category_id).count
    self_and_descendants.sum { |c| counts[c.id] || 0 }
  end
end
