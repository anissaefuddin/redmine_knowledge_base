// Progressive-enhancement block editor for KbArticle#content.
//
// It never changes the <textarea>'s name/id, only its visibility - the
// textarea stays the single source of truth submitted with the form.
// Blocks are parsed out of the textarea's existing Markdown on load and
// serialized back into it on every change, so the server-side flow
// (validation, KbArticle#snapshot_version, textilizable rendering) never
// needs to know blocks exist. If this script fails to load, the plain
// textarea still works.
(function () {
  'use strict';

  // Grouped the way Notion-style slash menus are, so the list stays
  // scannable as more block types get added over time - see BLOCK_GROUPS
  // below for the display order/labels of each group.
  var BLOCK_TYPES = [
    { type: 'h1', label: 'Big heading', hint: 'H1', group: 'basic' },
    { type: 'h2', label: 'Medium heading', hint: 'H2', group: 'basic' },
    { type: 'h3', label: 'Small heading', hint: 'H3', group: 'basic' },
    { type: 'bullet', label: 'Bulleted list', hint: '•', group: 'basic' },
    { type: 'numbered', label: 'Ordered list', hint: '1.', group: 'basic' },
    { type: 'todo', label: 'Todo list', hint: '☑', group: 'basic' },
    { type: 'quote', label: 'Quote', hint: '❝', group: 'basic' },
    { type: 'divider', label: 'Divider', hint: '—', group: 'basic' },
    { type: 'table', label: 'Table', hint: '▦', group: 'content' },
    { type: 'callout', label: 'Callout', hint: '❕', group: 'content' },
    { type: 'codeblock', label: 'Code block', hint: '</>', group: 'content' },
    { type: 'math', label: 'Math equation', hint: '∑', group: 'content' },
    { type: 'image', label: 'Image', hint: '▣', group: 'media' },
    { type: 'video', label: 'Video', hint: '▶', group: 'media' },
    { type: 'gdoc', label: 'Embed Google Docs/Sheets/Slides', hint: 'G', group: 'media' },
    { type: 'mermaid', label: 'Diagram (Mermaid)', hint: '◇', group: 'advanced' }
  ];

  var BLOCK_GROUPS = [
    { key: 'basic', label: 'Basic' },
    { key: 'content', label: 'Content' },
    { key: 'media', label: 'Media' },
    { key: 'advanced', label: 'Advanced' }
  ];

  var CALLOUT_VARIANTS = ['note', 'tip', 'important', 'warning', 'caution'];
  var LIST_TYPES = { bullet: true, numbered: true, todo: true };
  // Block types where a non-empty Enter should keep producing more of the
  // same type (a new list item, another quote line, another callout line)
  // instead of always dropping back to a plain paragraph. An empty Enter on
  // any of these still exits to a paragraph (or outdents first, for lists).
  var CONTINUABLE_TYPES = { bullet: true, numbered: true, todo: true, quote: true, callout: true };
  // Block types where Shift+Enter inserts a soft line break WITHIN the
  // block's own text (rendered as <br> on publish) instead of doing
  // whatever plain Enter does. Left out for h1/h2/h3 (ATX headings can't
  // span lines) and image/video/math/gdoc (single-value URL/expression
  // fields) - Shift+Enter there just falls back to the plain-Enter action.
  var SOFT_BREAK_TYPES = { paragraph: true, quote: true, callout: true, bullet: true, numbered: true, todo: true };
  var LIST_INDENT_UNIT = 4; // spaces per nesting level in the serialized Markdown
  var MAX_INDENT = 4;

  // Inline text formatting applied to a selection inside a block's text
  // input. Markers are chosen so bold/italic/underline/strike never share a
  // delimiter character with each other - that's what lets them nest/combine
  // correctly (e.g. selecting already-bolded text and applying italic on top
  // of it) instead of the toggle-detection logic getting confused about
  // which marker it's looking at.
  var INLINE_FORMATS = [
    { key: 'b', open: '**', close: '**', label: 'B', fmt: 'b', title: 'Bold (Ctrl/Cmd+B)' },
    { key: 'i', open: '_', close: '_', label: 'I', fmt: 'i', title: 'Italic (Ctrl/Cmd+I)' },
    { key: 'u', open: '<u>', close: '</u>', label: 'U', fmt: 'u', title: 'Underline (Ctrl/Cmd+U)' },
    { key: 'x', open: '~~', close: '~~', label: 'S', fmt: 'x', shift: true, title: 'Strikethrough (Ctrl/Cmd+Shift+X)' }
  ];

  // Wraps (or unwraps, toggle-style) the current selection of a text <input>
  // with a Markdown marker pair. Works whether the marker sits inside the
  // selection (selecting "**bold**" itself) or just outside it (selection is
  // "bold", markers are the two neighboring characters) - and combines
  // cleanly with other markers already present, in or around the selection.
  function wrapSelection(input, open, close) {
    var start = input.selectionStart;
    var end = input.selectionEnd;
    var value = input.value;
    var selected = value.slice(start, end);
    var before = value.slice(0, start);
    var after = value.slice(end);

    var innerWrapped = selected.length >= open.length + close.length &&
      selected.slice(0, open.length) === open &&
      selected.slice(selected.length - close.length) === close;
    var outerWrapped = !innerWrapped &&
      before.slice(before.length - open.length) === open &&
      after.slice(0, close.length) === close;

    if (innerWrapped) {
      var inner = selected.slice(open.length, selected.length - close.length);
      input.value = before + inner + after;
      input.setSelectionRange(start, start + inner.length);
    } else if (outerWrapped) {
      input.value = before.slice(0, before.length - open.length) + selected + after.slice(close.length);
      input.setSelectionRange(start - open.length, end - open.length);
    } else {
      input.value = before + open + selected + close + after;
      input.setSelectionRange(start + open.length, start + open.length + selected.length);
    }
  }

  function newBlock(type) {
    if (type === 'table') return { type: 'table', rows: [['Header 1', 'Header 2'], ['', '']], checked: false, indent: 0 };
    if (type === 'codeblock') return { type: 'codeblock', text: '', language: '', checked: false, indent: 0 };
    // "mermaid" is a slash-menu convenience that maps onto a regular
    // codeblock with the language pre-filled - buildCodeRow/render already
    // know how to draw any codeblock, no separate block type needed.
    if (type === 'mermaid') return { type: 'codeblock', text: 'graph TD;\n  A --> B;', language: 'mermaid', checked: false, indent: 0 };
    if (type === 'callout') return { type: 'callout', variant: 'note', text: '', checked: false, indent: 0 };
    return { type: type, text: '', checked: false, indent: 0 };
  }

  function escapeTableCell(text) {
    return (text || '').replace(/\|/g, '\\|');
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  }

  function sanitizeFilename(name) {
    return name.replace(/[/?%*:|"'<>\n\r]+/g, '_');
  }

  function clipboardFilename(mimeType) {
    var ext = (mimeType.split('/')[1] || 'png').replace('jpeg', 'jpg');
    var rand = Math.random().toString(36).slice(2, 7);
    return 'clipboard-' + Date.now() + '-' + rand + '.' + ext;
  }

  function debounce(fn, wait) {
    var timer = null;
    return function () {
      var args = arguments;
      var ctx = this;
      clearTimeout(timer);
      timer = setTimeout(function () { fn.apply(ctx, args); }, wait);
    };
  }

  // Uploads a file to Redmine's own /uploads endpoint (the same one its
  // built-in wiki/issue editors use for drag-drop images) and returns the
  // {filename, token} the caller needs both to reference the image inline
  // (![](filename)) and to register it with save_attachments on submit.
  function uploadFile(file, filename) {
    return fetch('/uploads.json?filename=' + encodeURIComponent(filename) + '&content_type=' + encodeURIComponent(file.type || 'application/octet-stream'), {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-CSRF-Token': csrfToken(),
        'Accept': 'application/json'
      },
      body: file
    }).then(function (res) {
      if (!res.ok) {
        if (res.status === 403) {
          throw new Error('You don\'t have permission to upload files. Ask an administrator to grant you the knowledge base article-editing permission.');
        }
        if (res.status === 413) {
          throw new Error('This file is too large to upload.');
        }
        throw new Error('Upload failed (' + res.status + '). Please try again.');
      }
      return res.json();
    }).then(function (json) {
      return { filename: filename, token: json.upload.token, id: json.upload.id };
    });
  }

  // Best-effort conversion of a Google Docs/Sheets/Slides/Drive share link
  // into its embeddable /preview (or /embed) URL. Falls back to the URL
  // as-is if the shape isn't recognized.
  function googleEmbedUrl(url) {
    var idMatch = /\/d\/([a-zA-Z0-9_-]+)/.exec(url);
    var id = idMatch ? idMatch[1] : null;
    if (!id) return url;
    if (url.indexOf('/spreadsheets/') !== -1) return 'https://docs.google.com/spreadsheets/d/' + id + '/preview';
    if (url.indexOf('/presentation/') !== -1) return 'https://docs.google.com/presentation/d/' + id + '/embed';
    if (url.indexOf('/document/') !== -1) return 'https://docs.google.com/document/d/' + id + '/preview';
    if (url.indexOf('drive.google.com/file/') !== -1) return 'https://drive.google.com/file/d/' + id + '/preview';
    return url;
  }

  function parseMarkdown(text) {
    var lines = (text || '').replace(/\r\n/g, '\n').split('\n');
    var blocks = [];
    var i = 0;
    // Index of the last raw line that was folded into blocks (used below to
    // detect "this line directly follows the previous one, no blank line in
    // between" - i.e. a Shift+Enter soft break rather than a deliberate new
    // paragraph, which always has a blank line separating it).
    var prevLineIndex = -2;

    while (i < lines.length) {
      var line = lines[i];
      var m;

      if (/^\s*$/.test(line)) {
        i++;
        continue;
      }

      if ((m = /^```\s*([a-zA-Z0-9_+-]*)\s*$/.exec(line))) {
        var codeLines = [];
        i++;
        while (i < lines.length && !/^```\s*$/.test(lines[i])) {
          codeLines.push(lines[i]);
          i++;
        }
        i++; // skip closing fence
        blocks.push({ type: 'codeblock', text: codeLines.join('\n'), language: m[1] || '', checked: false, indent: 0 });
        continue;
      }

      if ((m = /^>\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$/i.exec(line))) {
        var variant = m[1].toLowerCase();
        var calloutLines = [];
        i++;
        while (i < lines.length && /^>\s?/.test(lines[i])) {
          calloutLines.push(lines[i].replace(/^>\s?/, ''));
          i++;
        }
        blocks.push({ type: 'callout', variant: variant, text: calloutLines.join('\n'), checked: false, indent: 0 });
        continue;
      }

      if (/^\|.*\|\s*$/.test(line) && i + 1 < lines.length && /^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/.test(lines[i + 1])) {
        var rows = [line.split('|').slice(1, -1).map(function (c) { return c.trim(); })];
        i += 2; // header + separator
        while (i < lines.length && /^\|.*\|\s*$/.test(lines[i])) {
          rows.push(lines[i].split('|').slice(1, -1).map(function (c) { return c.trim(); }));
          i++;
        }
        blocks.push({ type: 'table', rows: rows, checked: false, indent: 0 });
        continue;
      }

      if ((m = /^(\s*)-\s+\[([ xX])\]\s+(.*)$/.exec(line))) {
        blocks.push({ type: 'todo', text: m[3], checked: /x/i.test(m[2]), indent: Math.round(m[1].length / LIST_INDENT_UNIT) });
      } else if ((m = /^(\s*)[-*]\s+(.*)$/.exec(line))) {
        blocks.push({ type: 'bullet', text: m[2], checked: false, indent: Math.round(m[1].length / LIST_INDENT_UNIT) });
      } else if ((m = /^(\s*)\d+\.\s+(.*)$/.exec(line))) {
        blocks.push({ type: 'numbered', text: m[2], checked: false, indent: Math.round(m[1].length / LIST_INDENT_UNIT) });
      } else if ((m = /^###\s+(.*)$/.exec(line))) blocks.push({ type: 'h3', text: m[1], checked: false, indent: 0 });
      else if ((m = /^##\s+(.*)$/.exec(line))) blocks.push({ type: 'h2', text: m[1], checked: false, indent: 0 });
      else if ((m = /^#\s+(.*)$/.exec(line))) blocks.push({ type: 'h1', text: m[1], checked: false, indent: 0 });
      else if (/^-{3,}\s*$/.test(line)) blocks.push({ type: 'divider', text: '', checked: false, indent: 0 });
      else if ((m = /^>\s?(.*)$/.exec(line))) blocks.push({ type: 'quote', text: m[1], checked: false, indent: 0 });
      else if ((m = /^!\[[^\]]*\]\(([^)]*)\)$/.exec(line))) blocks.push({ type: 'image', text: m[1], checked: false, indent: 0 });
      else if ((m = /^\[video\]\(([^)]*)\)$/.exec(line))) blocks.push({ type: 'video', text: m[1], checked: false, indent: 0 });
      else if ((m = /^\[embed:gdoc\]\(([^)]*)\)$/.exec(line))) blocks.push({ type: 'gdoc', text: m[1], checked: false, indent: 0 });
      else if ((m = /^\$\$(.+)\$\$$/.exec(line))) blocks.push({ type: 'math', text: m[1], checked: false, indent: 0 });
      else {
        // A plain, unmarked line that directly follows (no blank line
        // between) a paragraph or list item is that block's own Shift+Enter
        // soft break, not a new block - CommonMark's lazy-continuation rule
        // agrees (see the lineFor comment on quote/list serialization for
        // why quote doesn't need this same merge). Undoes exactly what
        // serialize() produces for a soft break, so save -> reload -> save
        // is stable and doesn't turn a break into a real new paragraph.
        var lastBlock = blocks[blocks.length - 1];
        var mergeable = lastBlock && (lastBlock.type === 'paragraph' || LIST_TYPES[lastBlock.type]) && prevLineIndex === i - 1;
        if (mergeable) {
          lastBlock.text += '\n' + line;
        } else {
          blocks.push({ type: 'paragraph', text: line, checked: false, indent: 0 });
        }
      }

      prevLineIndex = i;
      i++;
    }

    if (blocks.length === 0) blocks.push(newBlock('paragraph'));
    return blocks;
  }

  function lineFor(block) {
    var indentStr = ' '.repeat((block.indent || 0) * LIST_INDENT_UNIT);
    switch (block.type) {
      case 'h1': return '# ' + block.text;
      case 'h2': return '## ' + block.text;
      case 'h3': return '### ' + block.text;
      case 'todo': return indentStr + '- [' + (block.checked ? 'x' : ' ') + '] ' + block.text;
      case 'bullet': return indentStr + '- ' + block.text;
      case 'numbered': return indentStr + '1. ' + block.text;
      // Every physical line gets its own '>' prefix (not just the first),
      // so a Shift+Enter soft break inside one quote/callout block survives
      // a reload as a stable, self-consistent shape under our own parser -
      // see the parseMarkdown comment on the quote/callout branches.
      case 'quote': return block.text.split('\n').map(function (l) { return '> ' + l; }).join('\n');
      case 'callout':
        return '> [!' + (block.variant || 'note').toUpperCase() + ']\n' +
          block.text.split('\n').map(function (l) { return '> ' + l; }).join('\n');
      case 'math': return '$$' + block.text + '$$';
      case 'divider': return '---';
      case 'codeblock': return '```' + (block.language || '') + '\n' + block.text + '\n```';
      case 'table':
        return block.rows.map(function (row, ri) {
          var cells = '| ' + row.map(escapeTableCell).join(' | ') + ' |';
          if (ri === 0) cells += '\n| ' + row.map(function () { return '---'; }).join(' | ') + ' |';
          return cells;
        }).join('\n');
      case 'image': return '![](' + block.text + ')';
      case 'video': return '[video](' + block.text + ')';
      case 'gdoc': return '[embed:gdoc](' + block.text + ')';
      default: return block.text;
    }
  }

  function serialize(blocks) {
    var lines = [];
    blocks.forEach(function (block, i) {
      var prev = blocks[i - 1];
      var sameListRun = prev && LIST_TYPES[block.type] && LIST_TYPES[prev.type];
      // Consecutive quote blocks (produced by pressing Enter inside a quote)
      // must NOT get a blank line between them, or each one becomes its own
      // separate blockquote in Markdown instead of one continuous quote with
      // multiple lines - same reasoning as sameListRun above.
      var sameQuoteRun = prev && block.type === 'quote' && prev.type === 'quote';
      if (i > 0 && !sameListRun && !sameQuoteRun) lines.push('');
      lines.push(lineFor(block));
    });
    return lines.join('\n');
  }

  function KbBlockEditor(textarea) {
    this.textarea = textarea;
    this.blocks = parseMarkdown(textarea.value);
    this.slashMenuEl = null;
    this.uploadCounter = 900000;

    this.container = document.createElement('div');
    this.container.className = 'kb-block-editor';

    // Hidden inputs registered here survive re-renders (container.innerHTML
    // gets wiped on every render()) and follow the exact params[:attachments]
    // shape acts_as_attachable#save_attachments expects, so pasted/dropped
    // images get attached to the article on save just like the classic
    // file-picker widget below the editor does.
    this.attachmentsContainer = document.createElement('div');
    this.attachmentsContainer.className = 'kb-block-attachments';
    this.attachmentsContainer.style.display = 'none';

    textarea.style.display = 'none';
    textarea.insertAdjacentElement('afterend', this.attachmentsContainer);
    textarea.insertAdjacentElement('afterend', this.container);

    this.initialSerialized = textarea.value;
    this.submitting = false;
    this.inlineToolbarEl = null;
    this.bindDropZone();
    this.bindUnsavedChangesGuard();
    this.bindInlineFormatting();
    this.render();
  }

  // Warns before leaving the page with unwritten edits (closing the tab,
  // clicking away, browser back) - a long article is expensive to lose by
  // accident. Submitting the form itself is exempt, obviously.
  KbBlockEditor.prototype.bindUnsavedChangesGuard = function () {
    var self = this;
    var form = this.textarea.form;
    if (form) {
      form.addEventListener('submit', function () { self.submitting = true; });
    }
    window.addEventListener('beforeunload', function (e) {
      if (self.submitting) return;
      if (self.textarea.value === self.initialSerialized) return;
      e.preventDefault();
      e.returnValue = '';
    });
  };

  KbBlockEditor.prototype.sync = function () {
    this.textarea.value = serialize(this.blocks);
    this.textarea.dispatchEvent(new Event('change', { bubbles: true }));
  };

  KbBlockEditor.prototype.focusBlock = function (index) {
    var target = this.container.querySelector('[data-block-index="' + index + '"]');
    if (target) target.focus();
  };

  KbBlockEditor.prototype.currentFocusIndex = function () {
    var active = document.activeElement;
    if (active && this.container.contains(active) && active.hasAttribute('data-block-index')) {
      return parseInt(active.getAttribute('data-block-index'), 10);
    }
    return this.blocks.length - 1;
  };

  KbBlockEditor.prototype.insertAfter = function (index, block) {
    this.blocks.splice(index + 1, 0, block);
    this.sync();
    this.render();
    this.focusBlock(index + 1);
  };

  KbBlockEditor.prototype.removeAt = function (index) {
    if (this.blocks.length <= 1) return;
    this.blocks.splice(index, 1);
    this.sync();
    this.render();
    this.focusBlock(Math.max(0, index - 1));
  };

  // Applies a slash-menu pick either to an existing block (mid-document
  // rewrite) or as a fresh append from the bottom adder. Divider gets a
  // blank paragraph appended right after it, since there's nothing to type
  // into a divider itself - this keeps typing flowing without an extra click.
  KbBlockEditor.prototype.applyPick = function (type, index, isAppend) {
    var block = newBlock(type);
    if (isAppend) {
      this.blocks.push(block);
    } else {
      this.blocks[index] = block;
    }
    var focusIndex = isAppend ? this.blocks.length - 1 : index;
    if (type === 'divider') {
      this.blocks.splice(focusIndex + 1, 0, newBlock('paragraph'));
      focusIndex += 1;
    }
    this.sync();
    this.render();
    this.focusBlock(focusIndex);
  };

  // ---- Enter handling for "continuable" blocks (lists, quote, callout) ----
  //
  // Enter on a non-empty item continues the same block type (new sibling
  // item/line, same type and indent). Enter on an EMPTY item "pops" it: for
  // list types, one level of indent is removed and it keeps being a list
  // item, or - if already at the top level (true for quote/callout too,
  // which never carry indent) - it becomes a plain paragraph, exiting the
  // block entirely. That is what makes pressing Enter twice on the last
  // sub-item land back in the parent list, and a third time exit to text -
  // and, for quote/callout, a single Enter on an empty line exits to text.
  KbBlockEditor.prototype.handleContinuableEnter = function (index) {
    var block = this.blocks[index];
    if (block.text !== '') {
      var next = { type: block.type, text: '', checked: false, indent: block.indent || 0 };
      if (block.type === 'callout') next.variant = block.variant;
      this.insertAfter(index, next);
      return;
    }
    if (block.indent > 0) {
      block.indent -= 1;
      this.sync();
      this.render();
      this.focusBlock(index);
    } else {
      block.type = 'paragraph';
      delete block.checked;
      delete block.variant;
      this.sync();
      this.render();
      this.focusBlock(index);
    }
  };

  KbBlockEditor.prototype.handleListTab = function (index, outdent) {
    var block = this.blocks[index];
    if (outdent) {
      block.indent = Math.max(0, block.indent - 1);
    } else {
      // Can only indent one level deeper than the item directly above it,
      // matching how every other editor's Tab-to-nest behaves.
      var prev = this.blocks[index - 1];
      var maxAllowed = prev && LIST_TYPES[prev.type] ? prev.indent + 1 : 0;
      block.indent = Math.min(MAX_INDENT, Math.min(maxAllowed, block.indent + 1));
    }
    this.sync();
    this.render();
    this.focusBlock(index);
  };

  KbBlockEditor.prototype.closeSlashMenu = function () {
    if (this.slashMenuEl) {
      this.slashMenuEl.remove();
      this.slashMenuEl = null;
    }
  };

  // Positions the popup with position:fixed from the anchor's viewport
  // rect (not a CSS-relative ancestor), and flips it above the anchor when
  // it would otherwise overflow the bottom of the viewport - so it's never
  // clipped or hidden regardless of where in a long document it opens.
  KbBlockEditor.prototype.openSlashMenu = function (anchorEl, filter, onPick) {
    var self = this;
    this.closeSlashMenu();
    var matches = BLOCK_TYPES.filter(function (c) {
      return c.type.indexOf(filter) === 0 || c.label.toLowerCase().indexOf(filter) !== -1;
    });
    var menu = document.createElement('div');
    menu.className = 'kb-slash-menu';
    if (matches.length === 0) {
      var empty = document.createElement('div');
      empty.className = 'kb-slash-empty';
      empty.textContent = 'No matching blocks';
      menu.appendChild(empty);
    } else {
      // Group headers only appear above a group that actually has a match
      // left after filtering, so typing "/image" collapses straight down to
      // the Media group instead of showing every empty header too.
      BLOCK_GROUPS.forEach(function (g) {
        var inGroup = matches.filter(function (c) { return c.group === g.key; });
        if (inGroup.length === 0) return;

        var heading = document.createElement('div');
        heading.className = 'kb-slash-group-label';
        heading.textContent = g.label;
        menu.appendChild(heading);

        inGroup.forEach(function (c) {
          var item = document.createElement('div');
          item.className = 'kb-slash-item';
          var hint = document.createElement('span');
          hint.className = 'kb-slash-hint';
          hint.textContent = c.hint;
          item.appendChild(hint);
          item.appendChild(document.createTextNode(c.label));
          item.addEventListener('mousedown', function (e) {
            e.preventDefault();
            self.closeSlashMenu();
            onPick(c.type);
          });
          menu.appendChild(item);
        });
      });
    }

    document.body.appendChild(menu);
    var rect = anchorEl.getBoundingClientRect();
    var menuHeight = menu.offsetHeight;
    var openUp = rect.bottom + menuHeight + 8 > window.innerHeight;
    menu.style.left = Math.max(4, rect.left) + 'px';
    menu.style.top = (openUp ? rect.top - menuHeight - 4 : rect.bottom + 4) + 'px';
    this.slashMenuEl = menu;
  };

  // ---- Image upload (paste / drag-drop / file picker) ----

  KbBlockEditor.prototype.registerAttachment = function (token, filename) {
    this.uploadCounter += 1;
    var key = this.uploadCounter;
    var tokenInput = document.createElement('input');
    tokenInput.type = 'hidden';
    tokenInput.name = 'attachments[' + key + '][token]';
    tokenInput.value = token;
    var filenameInput = document.createElement('input');
    filenameInput.type = 'hidden';
    filenameInput.name = 'attachments[' + key + '][filename]';
    filenameInput.value = filename;
    this.attachmentsContainer.appendChild(tokenInput);
    this.attachmentsContainer.appendChild(filenameInput);
  };

  KbBlockEditor.prototype.uploadAndInsertImage = function (file, atIndex) {
    var self = this;
    var filename = file.name && !/^image\.\w+$/i.test(file.name)
      ? sanitizeFilename(file.name)
      : clipboardFilename(file.type || 'image/png');

    var targetIndex;
    var existing = this.blocks[atIndex];
    if (existing && existing.type === 'image' && !existing.text && !existing.uploading) {
      targetIndex = atIndex;
      existing.uploading = true;
    } else {
      targetIndex = atIndex + 1;
      this.blocks.splice(targetIndex, 0, { type: 'image', text: '', checked: false, indent: 0, uploading: true });
    }
    this.render();

    uploadFile(file, filename).then(function (result) {
      self.registerAttachment(result.token, result.filename);
      self.blocks[targetIndex].text = result.filename;
      self.blocks[targetIndex].attachmentId = result.id;
      self.blocks[targetIndex].uploading = false;
      self.sync();
      self.render();
    }).catch(function (err) {
      self.blocks[targetIndex].uploading = false;
      self.blocks[targetIndex].uploadError = err.message;
      self.render();
    });
  };

  // Lazily builds one TurndownService (HTML -> Markdown), with the GFM
  // plugin (tables/strikethrough/task lists) mixed in when available, so
  // pasting from Word/Google Docs/a web page keeps its structure instead
  // of landing as one flat blob of text.
  KbBlockEditor.prototype.htmlToMarkdown = function (html) {
    if (typeof TurndownService === 'undefined') return null;
    if (!this.turndownService) {
      this.turndownService = new TurndownService({
        headingStyle: 'atx',
        codeBlockStyle: 'fenced',
        bulletListMarker: '-'
      });
      if (typeof turndownPluginGfm !== 'undefined') {
        this.turndownService.use([
          turndownPluginGfm.tables,
          turndownPluginGfm.strikethrough,
          turndownPluginGfm.taskListItems
        ]);
      }
    }
    try {
      return this.turndownService.turndown(html);
    } catch (e) {
      return null;
    }
  };

  // Splits a pasted multi-line paste (raw Markdown text, or HTML from
  // another document converted to Markdown above) into proper blocks via
  // the same parser used to load existing content, instead of letting the
  // browser collapse it into one line inside a single <input>. Native
  // multi-line fields (code block textarea, table cells) already handle
  // paste correctly on their own and are left alone.
  KbBlockEditor.prototype.handleTextPaste = function (e) {
    var target = e.target;
    if (target.tagName === 'TEXTAREA') return;
    if (target.closest && target.closest('.kb-block-table-wrap')) return;

    var html = e.clipboardData.getData('text/html');
    var plain = e.clipboardData.getData('text/plain');
    var source = plain;

    if (html && /<(p|div|h[1-6]|ul|ol|li|table|br|strong|em|b|i|a|blockquote|pre|code)[ >]/i.test(html)) {
      var converted = this.htmlToMarkdown(html);
      if (converted) source = converted;
    }

    if (!source || source.indexOf('\n') === -1) return; // single line: normal paste is fine

    e.preventDefault();
    var index = this.currentFocusIndex();
    var currentBlock = this.blocks[index];
    var pastedBlocks = parseMarkdown(source);
    var NON_REPLACEABLE_EMPTY = { table: true, codeblock: true, divider: true };
    var replaceCurrent = currentBlock && currentBlock.text === '' && !NON_REPLACEABLE_EMPTY[currentBlock.type];

    var removeCount = replaceCurrent ? 1 : 0;
    var insertAt = replaceCurrent ? index : index + 1;
    var spliceArgs = [insertAt, removeCount].concat(pastedBlocks);
    Array.prototype.splice.apply(this.blocks, spliceArgs);

    this.sync();
    this.render();
    this.focusBlock(insertAt + pastedBlocks.length - 1);
  };

  KbBlockEditor.prototype.bindDropZone = function () {
    var self = this;

    this.container.addEventListener('paste', function (e) {
      var items = (e.clipboardData && e.clipboardData.items) || [];
      for (var i = 0; i < items.length; i++) {
        if (items[i].type && items[i].type.indexOf('image/') === 0) {
          e.preventDefault();
          var file = items[i].getAsFile();
          if (file) self.uploadAndInsertImage(file, self.currentFocusIndex());
          return;
        }
      }
      self.handleTextPaste(e);
    });

    this.container.addEventListener('dragover', function (e) { e.preventDefault(); });

    this.container.addEventListener('drop', function (e) {
      var files = (e.dataTransfer && e.dataTransfer.files) || [];
      var imageFiles = [];
      for (var i = 0; i < files.length; i++) {
        if (files[i].type && files[i].type.indexOf('image/') === 0) imageFiles.push(files[i]);
      }
      if (imageFiles.length === 0) return;
      e.preventDefault();
      var index = self.currentFocusIndex();
      imageFiles.forEach(function (file) {
        self.uploadAndInsertImage(file, index);
        index++;
      });
    });
  };

  // ---- Inline formatting (bold/italic/underline/strike) ----
  //
  // A small floating toolbar shows above any block text input while text is
  // selected inside it, and the same four styles are reachable via
  // Ctrl/Cmd+B/I/U and Ctrl/Cmd+Shift+X regardless of whether the toolbar is
  // visible. Both paths funnel through applyInlineFormat/wrapSelection, so
  // styles combine freely (bold+italic, bold+underline, etc.) - see the
  // wrapSelection comment for why that nesting works.

  function isFormattableInput(el) {
    return !!el && el.classList && el.classList.contains('kb-block-input') &&
      (el.tagName === 'TEXTAREA' || (el.tagName === 'INPUT' && el.type === 'text'));
  }

  KbBlockEditor.prototype.hideInlineToolbar = function () {
    if (this.inlineToolbarEl) {
      this.inlineToolbarEl.remove();
      this.inlineToolbarEl = null;
    }
  };

  KbBlockEditor.prototype.showInlineToolbar = function (input) {
    var self = this;
    this.hideInlineToolbar();

    var toolbar = document.createElement('div');
    toolbar.className = 'kb-inline-toolbar';
    INLINE_FORMATS.forEach(function (spec) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'kb-inline-toolbar-btn';
      btn.setAttribute('data-fmt', spec.fmt);
      btn.textContent = spec.label;
      btn.title = spec.title;
      // mousedown (not click) + preventDefault keeps the input focused and
      // its selection intact right up until we read it in applyInlineFormat.
      btn.addEventListener('mousedown', function (e) {
        e.preventDefault();
        self.applyInlineFormat(input, spec);
      });
      toolbar.appendChild(btn);
    });

    document.body.appendChild(toolbar);
    var rect = input.getBoundingClientRect();
    var toolbarWidth = toolbar.offsetWidth;
    var left = rect.left + (rect.width - toolbarWidth) / 2;
    toolbar.style.left = Math.max(4, left) + 'px';
    toolbar.style.top = (rect.top - toolbar.offsetHeight - 6) + 'px';
    this.inlineToolbarEl = toolbar;
  };

  KbBlockEditor.prototype.applyInlineFormat = function (input, spec) {
    wrapSelection(input, spec.open, spec.close);
    input.focus();
    input.dispatchEvent(new Event('input', { bubbles: true }));
  };

  KbBlockEditor.prototype.bindInlineFormatting = function () {
    var self = this;

    document.addEventListener('selectionchange', function () {
      var active = document.activeElement;
      if (!isFormattableInput(active) || !self.container.contains(active) || active.selectionStart === active.selectionEnd) {
        self.hideInlineToolbar();
        return;
      }
      self.showInlineToolbar(active);
    });

    this.container.addEventListener('keydown', function (e) {
      if (!isFormattableInput(e.target)) return;
      var mod = e.metaKey || e.ctrlKey;
      if (!mod) return;
      var key = e.key.toLowerCase();
      var spec = null;
      for (var i = 0; i < INLINE_FORMATS.length; i++) {
        if (INLINE_FORMATS[i].key === key && !!INLINE_FORMATS[i].shift === e.shiftKey) {
          spec = INLINE_FORMATS[i];
          break;
        }
      }
      if (!spec) return;
      e.preventDefault();
      self.applyInlineFormat(e.target, spec);
    });
  };

  // Renders a single-line text block (paragraph/heading/list/quote/image/video/gdoc).
  // A <textarea> (not <input>) so a type in SOFT_BREAK_TYPES can actually
  // show a Shift+Enter break while editing, not just when published - see
  // growTextRow and the Enter handling below. CSS makes it look and behave
  // like a plain single-line field until it actually grows past one line.
  function growTextRow(el) {
    el.rows = Math.max(1, el.value.split('\n').length);
  }

  KbBlockEditor.prototype.buildTextRow = function (block, index) {
    var self = this;
    var input = document.createElement('textarea');
    input.className = 'kb-block-input';
    input.setAttribute('data-block-index', index);
    input.value = block.text;
    input.rows = 1;
    if (block.type === 'image') input.placeholder = block.uploading ? 'Uploading image…' : 'Paste an image URL, or paste/drop an image directly…';
    if (block.type === 'video') input.placeholder = 'Paste a video URL…';
    if (block.type === 'math') input.placeholder = 'LaTeX formula, e.g. E = mc^2…';
    if (block.type === 'gdoc') input.placeholder = 'Google Docs/Sheets/Slides link (make sure sharing is set to "Anyone with the link")…';
    if (block.uploading) input.disabled = true;
    if (SOFT_BREAK_TYPES[block.type]) growTextRow(input);

    input.addEventListener('input', function () {
      block.text = input.value;
      self.sync();
      if (SOFT_BREAK_TYPES[block.type]) growTextRow(input);
      var m = /^\/([a-z0-9]*)$/i.exec(input.value);
      if (m) {
        self.openSlashMenu(input, m[1].toLowerCase(), function (type) {
          self.applyPick(type, index, false);
        });
      } else {
        self.closeSlashMenu();
      }
    });

    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && !self.slashMenuEl) {
        if (e.shiftKey && SOFT_BREAK_TYPES[block.type]) return; // let the browser insert the newline
        e.preventDefault();
        if (CONTINUABLE_TYPES[block.type]) {
          self.handleContinuableEnter(index);
        } else {
          self.insertAfter(index, newBlock('paragraph'));
        }
      } else if (e.key === 'Tab' && LIST_TYPES[block.type]) {
        e.preventDefault();
        self.handleListTab(index, e.shiftKey);
      } else if (e.key === 'Backspace' && input.value === '' && self.blocks.length > 1) {
        e.preventDefault();
        self.removeAt(index);
      } else if (e.key === 'Escape' && self.slashMenuEl) {
        self.closeSlashMenu();
      }
    });

    return input;
  };

  KbBlockEditor.prototype.buildCodeRow = function (block, index) {
    var self = this;
    var wrap = document.createElement('div');
    wrap.className = 'kb-block-code-wrap';

    var lang = document.createElement('input');
    lang.type = 'text';
    lang.className = 'kb-block-code-lang';
    lang.placeholder = 'language (e.g. bash, ruby, mermaid)…';
    lang.value = block.language || '';

    var preview = null;
    var updatePreview = null;

    if (block.language === 'mermaid' && typeof mermaid !== 'undefined') {
      preview = document.createElement('div');
      preview.className = 'kb-mermaid-preview';
      var renderSeq = 0;
      updatePreview = debounce(function () {
        var seq = ++renderSeq;
        var source = block.text.trim();
        if (!source) { preview.innerHTML = ''; return; }
        var id = 'kb-mermaid-preview-' + Date.now();
        mermaid.render(id, source).then(function (result) {
          if (seq === renderSeq) preview.innerHTML = result.svg;
        }).catch(function (err) {
          if (seq === renderSeq) {
            preview.innerHTML = '';
            preview.textContent = 'Invalid diagram: ' + (err && err.message ? err.message : err);
            preview.classList.add('kb-mermaid-preview-error');
          }
        });
      }, 400);
    }

    lang.addEventListener('input', function () {
      block.language = lang.value;
      self.sync();
      self.render(); // language change may toggle the mermaid preview pane
    });

    var textarea = document.createElement('textarea');
    textarea.className = 'kb-block-input kb-block-code-input';
    textarea.setAttribute('data-block-index', index);
    textarea.rows = Math.max(4, block.text.split('\n').length);
    textarea.value = block.text;
    textarea.addEventListener('input', function () {
      block.text = textarea.value;
      self.sync();
      textarea.rows = Math.max(4, textarea.value.split('\n').length);
      if (updatePreview) updatePreview();
    });
    textarea.addEventListener('keydown', function (e) {
      if (e.key === 'Backspace' && textarea.value === '' && self.blocks.length > 1) {
        e.preventDefault();
        self.removeAt(index);
      }
    });

    wrap.appendChild(lang);
    wrap.appendChild(textarea);
    if (preview) {
      wrap.appendChild(preview);
      updatePreview();
    }
    return wrap;
  };

  KbBlockEditor.prototype.buildTableRow = function (block, index) {
    var self = this;
    var wrap = document.createElement('div');
    wrap.className = 'kb-block-table-wrap';

    var table = document.createElement('table');
    table.className = 'kb-block-table';
    // Indexed the same shape as block.rows, so Enter can jump to "the same
    // column, one row down" - a plain <input> has no row/table awareness of
    // its own, and without this it would fall through to the browser's
    // default behavior for Enter in a form field, which is to submit the
    // form (there's nothing else here to prevent that).
    var cellInputsByRow = [];
    block.rows.forEach(function (row, ri) {
      var tr = document.createElement('tr');
      var rowInputs = [];
      row.forEach(function (cellText, ci) {
        var td = document.createElement(ri === 0 ? 'th' : 'td');
        var cellInput = document.createElement('input');
        cellInput.type = 'text';
        cellInput.value = cellText;
        if (ri === 0 && ci === 0) cellInput.setAttribute('data-block-index', index);
        cellInput.addEventListener('input', function () {
          block.rows[ri][ci] = cellInput.value;
          self.sync();
        });
        cellInput.addEventListener('keydown', function (e) {
          if (e.key !== 'Enter') return;
          e.preventDefault();
          var nextRow = cellInputsByRow[ri + 1];
          if (nextRow && nextRow[ci]) nextRow[ci].focus();
        });
        rowInputs.push(cellInput);
        td.appendChild(cellInput);
        tr.appendChild(td);
      });
      cellInputsByRow.push(rowInputs);
      table.appendChild(tr);
    });

    var controls = document.createElement('div');
    controls.className = 'kb-block-table-controls';

    var addRow = document.createElement('button');
    addRow.type = 'button';
    addRow.textContent = '+ baris';
    addRow.addEventListener('click', function () {
      block.rows.push(block.rows[0].map(function () { return ''; }));
      self.sync();
      self.render();
    });

    var addCol = document.createElement('button');
    addCol.type = 'button';
    addCol.textContent = '+ kolom';
    addCol.addEventListener('click', function () {
      block.rows.forEach(function (row) { row.push(''); });
      self.sync();
      self.render();
    });

    controls.appendChild(addRow);
    controls.appendChild(addCol);
    wrap.appendChild(table);
    wrap.appendChild(controls);
    return wrap;
  };

  KbBlockEditor.prototype.buildCalloutRow = function (block, index) {
    var self = this;
    var wrap = document.createElement('div');
    wrap.className = 'kb-block-callout-wrap kb-block-callout-' + block.variant;

    var select = document.createElement('select');
    select.className = 'kb-block-callout-variant';
    CALLOUT_VARIANTS.forEach(function (v) {
      var opt = document.createElement('option');
      opt.value = v;
      opt.textContent = v.charAt(0).toUpperCase() + v.slice(1);
      if (v === block.variant) opt.selected = true;
      select.appendChild(opt);
    });
    select.addEventListener('change', function () {
      block.variant = select.value;
      self.sync();
      self.render();
      self.focusBlock(index);
    });

    var input = document.createElement('textarea');
    input.className = 'kb-block-input';
    input.setAttribute('data-block-index', index);
    input.value = block.text;
    input.rows = 1;
    input.placeholder = 'Callout text…';
    growTextRow(input);
    input.addEventListener('input', function () {
      block.text = input.value;
      self.sync();
      growTextRow(input);
    });
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') {
        if (e.shiftKey) return; // let the browser insert the newline
        e.preventDefault();
        self.handleContinuableEnter(index);
      } else if (e.key === 'Backspace' && input.value === '' && self.blocks.length > 1) {
        e.preventDefault();
        self.removeAt(index);
      }
    });

    wrap.appendChild(select);
    wrap.appendChild(input);
    return wrap;
  };

  // Renders an image block's row: the URL/upload-state text input plus a
  // small button that opens a native file picker as an alternative to
  // pasting or dragging an image in directly.
  KbBlockEditor.prototype.buildImageRow = function (block, index) {
    var self = this;
    var wrap = document.createElement('div');
    wrap.className = 'kb-block-image-wrap';
    wrap.appendChild(self.buildTextRow(block, index));

    // Previewable when it's an external URL, or an attachment uploaded
    // this session (we know its id). A plain filename parsed back out of
    // existing content has no id available client-side, so it's shown as
    // text only until the page is reloaded (the real <img> on the show
    // page resolves it server-side regardless).
    var previewSrc = null;
    if (/^https?:\/\//i.test(block.text)) previewSrc = block.text;
    else if (block.attachmentId) previewSrc = '/attachments/download/' + block.attachmentId + '/' + encodeURIComponent(block.text);

    if (previewSrc && !block.uploading) {
      var preview = document.createElement('img');
      preview.className = 'kb-block-image-preview';
      preview.src = previewSrc;
      preview.alt = '';
      wrap.appendChild(preview);
    }

    var pickBtn = document.createElement('button');
    pickBtn.type = 'button';
    pickBtn.className = 'kb-block-image-pick';
    pickBtn.textContent = '📁 Upload';
    pickBtn.disabled = !!block.uploading;
    var fileInput = document.createElement('input');
    fileInput.type = 'file';
    fileInput.accept = 'image/*';
    fileInput.style.display = 'none';
    fileInput.addEventListener('change', function () {
      if (fileInput.files[0]) self.uploadAndInsertImage(fileInput.files[0], index - 1 >= 0 ? index - 1 : index);
      // uploadAndInsertImage re-renders, so this input is about to be removed;
      // nothing else to reset here.
    });
    pickBtn.addEventListener('click', function () { fileInput.click(); });
    wrap.appendChild(pickBtn);
    wrap.appendChild(fileInput);

    if (block.uploadError) {
      var err = document.createElement('div');
      err.className = 'kb-block-image-error';
      err.textContent = block.uploadError;
      wrap.appendChild(err);
    }

    return wrap;
  };

  KbBlockEditor.prototype.render = function () {
    this.container.innerHTML = '';
    this.slashMenuEl = null;
    this.hideInlineToolbar();
    var self = this;
    var numCounters = {};

    this.blocks.forEach(function (block, index) {
      if (block.type === 'numbered') {
        numCounters[block.indent] = (numCounters[block.indent] || 0) + 1;
        Object.keys(numCounters).forEach(function (lvl) {
          if (Number(lvl) > block.indent) delete numCounters[lvl];
        });
      } else if (!LIST_TYPES[block.type]) {
        numCounters = {};
      }

      var row = document.createElement('div');
      row.className = 'kb-block-row kb-block-' + block.type;
      if (LIST_TYPES[block.type] && block.indent) {
        row.style.marginLeft = (block.indent * 22) + 'px';
      }

      if (block.type === 'divider') {
        row.appendChild(document.createElement('hr'));
      } else if (block.type === 'codeblock') {
        row.appendChild(self.buildCodeRow(block, index));
      } else if (block.type === 'table') {
        row.appendChild(self.buildTableRow(block, index));
      } else if (block.type === 'callout') {
        row.appendChild(self.buildCalloutRow(block, index));
      } else if (block.type === 'image') {
        row.appendChild(self.buildImageRow(block, index));
      } else {
        var marker = document.createElement('span');
        marker.className = 'kb-block-marker';
        if (block.type === 'todo') {
          var checkbox = document.createElement('input');
          checkbox.type = 'checkbox';
          checkbox.checked = block.checked;
          checkbox.addEventListener('change', function () {
            block.checked = checkbox.checked;
            self.sync();
          });
          marker.appendChild(checkbox);
        } else if (block.type === 'bullet') {
          marker.textContent = '•';
        } else if (block.type === 'numbered') {
          marker.textContent = (numCounters[block.indent] || 1) + '.';
        } else if (block.type === 'quote') {
          marker.classList.add('kb-block-quote-bar');
        } else if (block.type === 'math') {
          marker.textContent = '∑';
        } else if (block.type === 'gdoc') {
          marker.textContent = 'G';
        }
        row.appendChild(marker);
        row.appendChild(self.buildTextRow(block, index));
      }

      var del = document.createElement('button');
      del.type = 'button';
      del.className = 'kb-block-delete';
      del.textContent = '×';
      del.setAttribute('aria-label', 'Delete block');
      del.addEventListener('click', function () { self.removeAt(index); });
      row.appendChild(del);

      self.container.appendChild(row);
    });

    var adder = document.createElement('div');
    adder.className = 'kb-block-adder';
    var adderInput = document.createElement('input');
    adderInput.type = 'text';
    adderInput.placeholder = "Type '/' to search blocks…";

    adderInput.addEventListener('input', function () {
      var m = /^\/([a-z0-9]*)$/i.exec(adderInput.value);
      if (m) {
        self.openSlashMenu(adderInput, m[1].toLowerCase(), function (type) {
          adderInput.value = '';
          self.applyPick(type, null, true);
        });
      } else {
        self.closeSlashMenu();
      }
    });

    adderInput.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && !self.slashMenuEl && adderInput.value.trim()) {
        e.preventDefault();
        self.blocks.push({ type: 'paragraph', text: adderInput.value, checked: false, indent: 0 });
        self.sync();
        self.render();
        self.focusBlock(self.blocks.length - 1);
      }
    });

    adder.appendChild(adderInput);
    this.container.appendChild(adder);
  };

  document.addEventListener('DOMContentLoaded', function () {
    var textarea = document.getElementById('kb_article_content');
    if (textarea) new KbBlockEditor(textarea);
  });
})();
