# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Covers the SSRF guards in KbLinkPreviewsController: only http(s), and any
# resolved address in a private/loopback/link-local range is blocked -
# checked before the request ever goes out.
class KbLinkPreviewsControllerTest < ActionController::TestCase
  tests KbLinkPreviewsController

  def setup
    @project = Project.find(1)
    @contributor = User.generate!
    kb_role_for(@contributor, :add_kb_articles)

    @viewer = User.generate!
    kb_role_for(@viewer)
  end

  def test_viewer_without_edit_permission_cannot_fetch_previews
    kb_login_as(@viewer)
    compatible_request :get, :show, url: 'http://example.com'
    assert_response :forbidden
  end

  def test_loopback_url_is_blocked
    kb_login_as(@contributor)
    compatible_request :get, :show, url: 'http://127.0.0.1/'
    assert_response :unprocessable_entity
  end

  def test_localhost_hostname_is_blocked
    kb_login_as(@contributor)
    compatible_request :get, :show, url: 'http://localhost/'
    assert_response :unprocessable_entity
  end

  def test_private_ip_literal_is_blocked
    kb_login_as(@contributor)
    compatible_request :get, :show, url: 'http://10.0.0.5/'
    assert_response :unprocessable_entity
  end

  def test_non_http_scheme_is_blocked
    kb_login_as(@contributor)
    compatible_request :get, :show, url: 'file:///etc/passwd'
    assert_response :unprocessable_entity
  end
end
