# frozen_string_literal: true

module RedmineKnowledgeBase
  module Hooks
    class ViewsLayoutsHook < Redmine::Hook::ViewListener
      def view_layouts_base_html_head(context = {})
        stylesheet_link_tag(:redmine_knowledge_base, plugin: 'redmine_knowledge_base')
      end
    end
  end
end
