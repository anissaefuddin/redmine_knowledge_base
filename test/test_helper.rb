# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

module RedmineKnowledgeBase
  module TestHelpers
    # A role granted exactly the given plugin permissions (plus
    # :view_knowledge_base unless the caller already asked for it), assigned
    # to +user+ as a member of +project+. The permission checks this plugin
    # makes are all global (allowed_to?(..., nil, global: true)), so any
    # project membership works as the "somewhere" that grants the role.
    def kb_role_for(user, *permissions, project: Project.find(1))
      permissions = permissions.dup
      permissions.unshift(:view_knowledge_base) unless permissions.include?(:view_knowledge_base)
      role = Role.generate!(permissions: permissions)
      User.add_to_project(user, project, role)
      role
    end

    def kb_login_as(user)
      @request.session[:user_id] = user.id
    end

    def compatible_request(type, action, parameters = {})
      send(type, action, params: parameters)
    end
  end
end

ActionController::TestCase.include RedmineKnowledgeBase::TestHelpers
