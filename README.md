# Redmine Knowledge Base

**Version:** 0.2.0
**Author:** [anissaefuddin](https://github.com/anissaefuddin)
**Requires:** Redmine 6.1 or higher (no extra gems — nothing to add to `Gemfile.local`)

Cross-project knowledge base plugin for Redmine — a single source of truth for documentation referenced across multiple projects, instead of duplicating wiki pages inside each one. Articles live in one global knowledge base, organized into a category tree, and can be linked to ("implemented in") any number of projects.

## Features

- **Global "Knowledge Base" menu**, independent of any single project — access is controlled by role permissions, not project membership
- **Category tree** (unlimited nesting) with per-category visibility restriction to specific **groups and/or roles**
- **Notion-style block editor** — type `/` to insert headings, lists, todo checklists, quotes, toggles, tables, callouts, code blocks (with syntax highlighting), math equations (KaTeX), 2-up columns, images, video embeds, Google Docs/Sheets/Slides embeds, link-preview bookmarks, PDF/file previews, Mermaid diagrams, and synced blocks (edit once, updates everywhere it's embedded)
- **Rich text editing**: Bold/Italic/Underline/Strikethrough via a floating toolbar or Ctrl/Cmd+B/I/U/Shift+X, freely combinable; paste from Word/Google Docs/any webpage auto-converts to clean Markdown (HTML → Markdown via a vendored Turndown.js)
- **Full version history** on every article, with a diff viewer to compare any two versions and one-click restore
- **Tags**, admin-managed, with quick-create from the article editor
- **Draft/Published** status, view counters, pinned articles, related-article cross-linking
- **Trash** (soft delete) with restore or permanent delete
- **Saved searches**, per user
- **Granular permission tiers** (see below) instead of an all-or-nothing admin switch
- Everything (KaTeX, Mermaid, Turndown) is **vendored locally** in `assets/` — no CDN or internet access needed at runtime

## Permissions

Granted per role under **Administration > Roles and permissions > Knowledge base** (works for the built-in "Non member" role too, so access doesn't require project membership):

| Permission | Grants |
|---|---|
| **View knowledge base** | Read-only access to the whole knowledge base |
| **Add articles** (`add_kb_articles`) | Create new articles |
| **Edit own articles** (`edit_own_kb_articles`) | Edit/delete only articles the user authored |
| **Manage articles** (`manage_kb_articles`) | Full control over *every* article (edit, delete, pin, restore versions, trash) — a superset of the two above |
| **Manage categories** (`manage_kb_categories`) | Create/edit/delete categories, set group/role restrictions |
| **Manage tags** (`manage_kb_tags`) | Create/edit/delete tags |

A typical setup: give everyone **View**, a "Contributor" role **Add + Edit own**, and an "Editor"/"Admin" role **Manage articles + Manage categories + Manage tags**. Redmine system administrators always have full access regardless of role.

## Installation (manual / from this zip)

1. **Unzip into the `plugins` directory** of your Redmine installation, using `redmine_knowledge_base` as the folder name:

   ```bash
   cd /path/to/redmine/plugins
   unzip /path/to/redmine_knowledge_base.zip -d redmine_knowledge_base
   ```

   If the zip already contains a top-level `redmine_knowledge_base/` folder, unzip directly into `plugins/` instead and skip the `-d` target. Either way, double-check the result is `plugins/redmine_knowledge_base/init.rb`, not `plugins/redmine_knowledge_base/redmine_knowledge_base/init.rb`.

2. **Back up your database**, then run the plugin's migrations from your Redmine root (this is Redmine's own official recommendation before running any plugin migration):

   ```bash
   cd /path/to/redmine
   RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_knowledge_base
   ```

3. **Restart Redmine** (Passenger, Puma, or whatever application server you use).

4. **Verify it loaded**: go to **Administration > Plugins** — "Redmine Knowledge Base" (0.2.0) should be listed.

5. **Grant permissions**: still as administrator, go to **Administration > Roles and permissions**. Under the **Knowledge base** section, grant at least **View knowledge base** to every role that should see the menu (add it to "Non member" too if it should be visible without project membership), and grant the other permissions as appropriate per role (see the Permissions table above).

That's it — no `bundle install` is required, this plugin has no gem dependencies of its own.

### Docker / docker-compose

If Redmine runs in Docker, unzip the plugin into the host directory/volume that's bind-mounted to the container's `plugins` folder, then run the migration and restart through the container:

```bash
# on the host, plugins/ already bind-mounted into the container
unzip redmine_knowledge_base.zip -d /path/to/host/redmine/plugins/redmine_knowledge_base

docker compose exec redmine bundle exec rake redmine:plugins:migrate NAME=redmine_knowledge_base RAILS_ENV=production
docker compose restart redmine
```

If your image auto-runs plugin migrations on boot (e.g. the official `redmine` image with `REDMINE_PLUGINS_MIGRATE=1`), a plain `docker compose restart redmine` after unzipping is enough — the migrate step above becomes optional.

### Verifying the install

- The **Knowledge Base** item should appear in the top application menu for users whose role has the **View knowledge base** permission.
- `Administration > Roles and permissions` should show a **Knowledge base** section with the 6 permissions listed above.
- Creating a category and an article, then reloading the article editor, should show a block-based editor (not a plain textarea) below the title field.

If the editor falls back to a plain textarea, check the browser console for a 404 on `/plugin_assets/redmine_knowledge_base/...` — that usually means the asset pipeline needs a manual precompile in production:

```bash
RAILS_ENV=production bundle exec rake redmine:plugins:assets NAME=redmine_knowledge_base
```

## Uninstallation

```bash
cd /path/to/redmine
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_knowledge_base VERSION=0
rm -rf plugins/redmine_knowledge_base
```

Then restart Redmine.

## Upgrading

Replace the `plugins/redmine_knowledge_base` folder with the contents of the new zip (keep the folder name), then:

```bash
cd /path/to/redmine
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_knowledge_base
```

Restart Redmine afterward. Migrations are additive/idempotent — re-running against an already-migrated install is a no-op.

## License

See repository for license details.
