# frozen_string_literal: true

module RedmineKnowledgeBase
  module Hooks
    class ViewsLayoutsHook < Redmine::Hook::ViewListener
      def view_layouts_base_html_head(context = {})
        output = stylesheet_link_tag(:redmine_knowledge_base, plugin: 'redmine_knowledge_base')

        controller = context[:controller]

        if controller.is_a?(KbArticlesController) && %w[new create edit update].include?(controller.action_name)
          # mermaid.min.js must load before kb_block_editor.js: the editor's
          # mermaid live-preview checks `typeof mermaid` synchronously while
          # building the code block row.
          output += javascript_include_tag('mermaid.min', plugin: 'redmine_knowledge_base')
          output += javascript_include_tag(:kb_block_editor, plugin: 'redmine_knowledge_base')
        end

        if controller.is_a?(KbArticlesController) && controller.action_name == 'show'
          article = controller.instance_variable_get(:@article)
          content = article&.content.to_s

          if content.match?(/\$.+\$/)
            output += stylesheet_link_tag('katex/katex.min', plugin: 'redmine_knowledge_base')
            output += javascript_include_tag('katex.min', plugin: 'redmine_knowledge_base')
            output += javascript_include_tag('katex-auto-render.min', plugin: 'redmine_knowledge_base')
          end

          output += javascript_include_tag('mermaid.min', plugin: 'redmine_knowledge_base') if content.include?('```mermaid')

          output += javascript_include_tag(:kb_render_enhance, plugin: 'redmine_knowledge_base')
        end

        output
      end
    end
  end
end
