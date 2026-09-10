# frozen_string_literal: true

module KnowledgeBaseHelper
  # Indented [label, id] pairs for a <select>, in tree order. Excludes the
  # given category and all of its descendants so a category can never be
  # made its own ancestor.
  def kb_category_tree_options(exclude: nil)
    exclude_ids = exclude ? exclude.self_and_descendants.map(&:id) : []
    options = []
    walk = lambda do |nodes, depth|
      nodes.each do |node|
        next if exclude_ids.include?(node.id)

        options << ["#{'—' * depth} #{node.name}".strip, node.id]
        walk.call(node.loaded_children || node.children, depth + 1)
      end
    end
    walk.call(KbCategory.build_tree(KbCategory.sorted.to_a), 0)
    options
  end

  def kb_status_label(article)
    article.published? ? l(:label_kb_status_published) : l(:label_kb_status_draft)
  end

  def kb_status_css_class(article)
    article.published? ? 'kb-status-published' : 'kb-status-draft'
  end

  # Status is a lifecycle state, not metadata like tags - render it as a
  # dot-indicator badge so it's visually distinct from tag pills instead of
  # looking like just another tag.
  def kb_status_badge(article)
    content_tag(:span, class: "kb-status-badge #{kb_status_css_class(article)}") do
      content_tag(:span, '', class: 'kb-status-dot') + kb_status_label(article)
    end
  end

  # "Restricted to groups: X, Y — Roles: A, B", assembled from only
  # whichever of the two restriction axes the category actually has
  # configured (see KbCategory#visible?).
  def kb_restriction_tooltip(category)
    parts = []
    parts << "#{l(:label_kb_restricted_to_groups)}: #{category.groups.map(&:name).join(', ')}" if category.groups.any?
    parts << "#{l(:label_kb_restricted_to_roles)}: #{category.roles.map(&:name).join(', ')}" if category.roles.any?
    parts.join(' — ')
  end
end
