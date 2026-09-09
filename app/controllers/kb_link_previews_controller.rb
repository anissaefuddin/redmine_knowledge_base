# frozen_string_literal: true

require 'ipaddr'
require 'resolv'

# Fetches a URL's <title>/description/favicon server-side for the bookmark
# block - a browser can't read another origin's HTML itself (no CORS), so
# this can't be done client-side. Since it's a plugin-controlled endpoint
# that fetches whatever URL an article author pastes, it's deliberately
# defensive against SSRF: http(s) only, private/loopback/link-local IPs
# blocked (checked on every redirect hop, not just the first URL), a small
# number of redirects, a response size cap, and HTML-only responses.
class KbLinkPreviewsController < ApplicationController
  include RedmineKnowledgeBase::Authorization

  before_action :require_login
  before_action :require_kb_can_upload

  MAX_RESPONSE_BYTES = 300_000
  MAX_REDIRECTS = 3
  REQUEST_TIMEOUT = 5

  BLOCKED_IP_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
    172.16.0.0/12 192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4
    ::1/128 fc00::/7 fe80::/10
  ].map { |cidr| IPAddr.new(cidr) }.freeze

  def show
    html, final_url = fetch_html(params[:url].to_s.strip)
    if html.nil?
      render json: { error: 'Could not fetch a preview for this link.' }, status: :unprocessable_entity
      return
    end

    render json: extract_metadata(html, final_url)
  end

  private

  def fetch_html(url, redirects_left = MAX_REDIRECTS)
    uri = safe_uri(url)
    return [nil, nil] unless uri

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                    open_timeout: REQUEST_TIMEOUT, read_timeout: REQUEST_TIMEOUT) do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'RedmineKnowledgeBase-LinkPreview/1.0'
      request['Accept'] = 'text/html'
      http.request(request)
    end

    case response
    when Net::HTTPRedirection
      return [nil, nil] if redirects_left <= 0

      location = response['location']
      return [nil, nil] if location.blank?

      fetch_html(URI.join(uri, location).to_s, redirects_left - 1)
    when Net::HTTPSuccess
      return [nil, nil] unless (response.content_type || '').include?('text/html')

      [response.body.to_s.byteslice(0, MAX_RESPONSE_BYTES), uri.to_s]
    else
      [nil, nil]
    end
  rescue StandardError
    [nil, nil]
  end

  # Parses, restricts to http(s), and resolves+checks every A/AAAA record
  # for the host - not just using the hostname string - so a DNS answer
  # pointing at a private/loopback address is caught before any request
  # goes out, including on each hop of a redirect chain.
  def safe_uri(url)
    uri = URI.parse(url)
    return nil unless uri.is_a?(URI::HTTP) && uri.host.present?

    addresses = Resolv.getaddresses(uri.host)
    return nil if addresses.empty?

    blocked = addresses.any? do |address|
      ip = IPAddr.new(address)
      BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
    rescue IPAddr::Error
      true
    end
    return nil if blocked

    uri
  rescue URI::InvalidURIError, Resolv::ResolvError
    nil
  end

  def extract_metadata(html, url)
    doc = Nokogiri::HTML(html)
    title = doc.at_css('meta[property="og:title"]')&.[]('content').presence || doc.at_css('title')&.text
    description = doc.at_css('meta[property="og:description"]')&.[]('content').presence ||
                  doc.at_css('meta[name="description"]')&.[]('content')
    favicon_href = doc.at_css('link[rel="icon"]')&.[]('href').presence ||
                   doc.at_css('link[rel="shortcut icon"]')&.[]('href').presence

    {
      title: title.to_s.strip.truncate(200).presence,
      description: description.to_s.strip.truncate(300).presence,
      favicon: resolve_favicon(favicon_href, url)
    }
  end

  def resolve_favicon(favicon_href, base_url)
    URI.join(base_url, favicon_href.presence || '/favicon.ico').to_s
  rescue URI::InvalidURIError
    nil
  end
end
