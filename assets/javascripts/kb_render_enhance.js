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

  // The block editor packs alignment and a drag-resized width as
  // "key:value;key:value" into the Markdown title slot (![caption](url
  // "align:center;width:400")), which the Markdown renderer turns into a
  // plain title attribute - not visible styling, and it'd show as a browser
  // tooltip left as-is. Wraps the image in a <figure> with the matching
  // kb-image-align-* class, applies the width as real inline style, and
  // turns its alt text (the caption) into a real <figcaption> underneath -
  // mirroring what the editor itself shows while writing.
  function renderImageAlignmentAndCaptions() {
    document.querySelectorAll('.wiki img').forEach(function (img) {
      var titleAttr = img.getAttribute('title') || '';
      var attrs = {};
      titleAttr.split(';').forEach(function (pair) {
        var kv = pair.split(':');
        if (kv[0] && kv[1] !== undefined) attrs[kv[0].trim()] = kv[1].trim();
      });
      var caption = img.getAttribute('alt');
      if (!attrs.align && !attrs.width && !caption) return; // plain image, nothing to add

      if (attrs.align || attrs.width) img.removeAttribute('title');
      if (attrs.width && attrs.align !== 'full') img.style.width = attrs.width + 'px';

      var figure = document.createElement('figure');
      figure.className = 'kb-image-align-' + (attrs.align || 'left');
      img.replaceWith(figure);
      figure.appendChild(img);

      if (caption) {
        var figcaption = document.createElement('figcaption');
        figcaption.textContent = caption;
        figure.appendChild(figcaption);
      }
    });
  }

  // The pdf block writes a plain [pdf](/attachments/download/ID/name.pdf
  // "name.pdf") link. Only ever swaps in an <iframe> for a same-origin
  // attachment download that's actually a .pdf - never an arbitrary URL,
  // since this loads content into a live frame on the page.
  function renderPdfEmbeds() {
    document.querySelectorAll('.wiki a').forEach(function (link) {
      if (link.textContent !== 'pdf') return;
      var href = link.getAttribute('href') || '';
      if (!/^\/attachments\/download\/\d+\/[^/]+\.pdf$/i.test(href)) return;

      var iframe = document.createElement('iframe');
      iframe.className = 'kb-pdf-embed';
      iframe.src = href;
      iframe.title = link.getAttribute('title') || 'PDF preview';

      var parent = link.parentElement;
      if (parent && parent.tagName === 'P' && parent.childNodes.length === 1) {
        parent.replaceWith(iframe);
      } else {
        link.replaceWith(iframe);
      }
    });
  }

  // The bookmark block writes [bookmark](URL "base64(JSON metadata)"). Swaps
  // the plain link for the same card markup the editor itself shows while
  // writing (see kb_block_editor.js's buildBookmarkRow).
  function renderBookmarkCards() {
    document.querySelectorAll('.wiki a').forEach(function (link) {
      if (link.textContent !== 'bookmark') return;
      var href = link.getAttribute('href') || '';
      var titleAttr = link.getAttribute('title') || '';
      var meta;
      try { meta = JSON.parse(atob(titleAttr)); } catch (e) { return; }
      if (!meta || !meta.title) return;

      var card = document.createElement('a');
      card.className = 'kb-bookmark-card';
      card.href = href;
      card.target = '_blank';
      card.rel = 'noopener';

      if (meta.favicon) {
        var favicon = document.createElement('img');
        favicon.className = 'kb-bookmark-favicon';
        favicon.src = meta.favicon;
        favicon.alt = '';
        card.appendChild(favicon);
      }

      var textWrap = document.createElement('div');
      textWrap.className = 'kb-bookmark-text';
      var titleEl = document.createElement('div');
      titleEl.className = 'kb-bookmark-title';
      titleEl.textContent = meta.title;
      textWrap.appendChild(titleEl);
      if (meta.description) {
        var descEl = document.createElement('div');
        descEl.className = 'kb-bookmark-desc';
        descEl.textContent = meta.description;
        textWrap.appendChild(descEl);
      }
      var urlEl = document.createElement('div');
      urlEl.className = 'kb-bookmark-url';
      urlEl.textContent = href;
      textWrap.appendChild(urlEl);
      card.appendChild(textWrap);

      var parent = link.parentElement;
      if (parent && parent.tagName === 'P' && parent.childNodes.length === 1) {
        parent.replaceWith(card);
      } else {
        link.replaceWith(card);
      }
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    renderMermaidBlocks();
    renderMath();
    renderGoogleEmbeds();
    renderImageAlignmentAndCaptions();
    renderPdfEmbeds();
    renderBookmarkCards();
  });
})();
