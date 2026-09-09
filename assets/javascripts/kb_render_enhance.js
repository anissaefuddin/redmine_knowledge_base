// Post-processes the already-rendered .wiki content on an article's show
// page: turns ```mermaid code blocks into diagrams and $...$/$$...$$ text
// into KaTeX math. Both libraries are optional (only loaded by the plugin's
// view hook when the article's content actually needs them) - every call
// here checks for the global before using it, so this script is a no-op
// with no libraries loaded.
(function () {
  'use strict';

  function renderMermaidBlocks() {
    if (typeof mermaid === 'undefined') return;
    var codes = document.querySelectorAll('.wiki pre code[data-language="mermaid"]');
    if (codes.length === 0) return;

    mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'strict' });

    codes.forEach(function (code, i) {
      var pre = code.closest('pre');
      if (!pre) return;
      var source = code.textContent;
      var container = document.createElement('div');
      container.className = 'kb-mermaid-diagram';
      pre.replaceWith(container);

      var id = 'kb-mermaid-' + Date.now() + '-' + i;
      mermaid.render(id, source).then(function (result) {
        container.innerHTML = result.svg;
      }).catch(function (err) {
        container.className = 'kb-mermaid-error';
        container.textContent = 'Gagal me-render diagram Mermaid: ' + (err && err.message ? err.message : err);
      });
    });
  }

  function renderMath() {
    if (typeof renderMathInElement === 'undefined') return;
    document.querySelectorAll('.wiki').forEach(function (el) {
      renderMathInElement(el, {
        delimiters: [
          { left: '$$', right: '$$', display: true },
          { left: '$', right: '$', display: false }
        ],
        throwOnError: false
      });
    });
  }

  // Turns the plain `[embed:gdoc](URL)` link the editor writes into an
  // actual <iframe> preview. Only ever targets docs.google.com/
  // drive.google.com - never an arbitrary URL - since this is rendering
  // user-authored article content into a live frame.
  function googleEmbedUrl(url) {
    var idMatch = /\/d\/([a-zA-Z0-9_-]+)/.exec(url);
    var id = idMatch ? idMatch[1] : null;
    if (!id) return null;
    if (url.indexOf('/spreadsheets/') !== -1) return 'https://docs.google.com/spreadsheets/d/' + id + '/preview';
    if (url.indexOf('/presentation/') !== -1) return 'https://docs.google.com/presentation/d/' + id + '/embed';
    if (url.indexOf('/document/') !== -1) return 'https://docs.google.com/document/d/' + id + '/preview';
    if (url.indexOf('drive.google.com/file/') !== -1) return 'https://drive.google.com/file/d/' + id + '/preview';
    return null;
  }

  function renderGoogleEmbeds() {
    var links = document.querySelectorAll('.wiki a');
    links.forEach(function (link) {
      if (link.textContent !== 'embed:gdoc') return;
      var href = link.getAttribute('href') || '';
      var host;
      try { host = new URL(href, window.location.href).hostname; } catch (e) { return; }
      if (host !== 'docs.google.com' && host !== 'drive.google.com') return;
      var embedUrl = googleEmbedUrl(href);
      if (!embedUrl) return;

      var wrap = document.createElement('div');
      wrap.className = 'kb-gdoc-embed';
      var iframe = document.createElement('iframe');
      iframe.src = embedUrl;
      iframe.loading = 'lazy';
      iframe.setAttribute('allowfullscreen', 'true');
      wrap.appendChild(iframe);

      var parent = link.parentElement;
      if (parent && parent.tagName === 'P' && parent.childNodes.length === 1) {
        parent.replaceWith(wrap);
      } else {
        link.replaceWith(wrap);
      }
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    renderMermaidBlocks();
    renderMath();
    renderGoogleEmbeds();
  });
})();
