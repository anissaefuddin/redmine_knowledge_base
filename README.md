# Redmine Knowledge Base

**Version:** 0.1.0
**Author:** [anissaefuddin](https://github.com/anissaefuddin)
**Requires:** Redmine 6.1 or higher

Cross-project knowledge base plugin for Redmine — a single source of truth for documentation referenced across multiple projects. Instead of duplicating wiki pages inside each project, articles live in one global knowledge base and can be linked to (implemented in) any number of projects, with categories, group-based visibility restrictions, and full version history.

## Features

- Global "Knowledge Base" menu, independent of any single project
- Categories and articles with a version history for every edit
- Articles can be linked to multiple projects ("Implemented in projects")
- Optional visibility restriction per category to specific groups
- Single global permission (`view_knowledge_base`) grantable per role, including the built-in "Non member" role, so access does not depend on project membership

## Installation

1. Clone this repository into your Redmine installation's `plugins` directory, using `redmine_knowledge_base` as the folder name:

   ```bash
   cd /path/to/redmine/plugins
   git clone https://github.com/anissaefuddin/redmine_knowledge_base.git
   ```

2. Install any plugin dependencies (bundler):

   ```bash
   cd /path/to/redmine
   bundle install
   ```

3. Run the plugin's database migrations:

   ```bash
   RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_knowledge_base
   ```

4. Restart Redmine (Passenger, Puma, or your application server).

5. Log in as an administrator and go to **Administration > Roles and permissions**, then grant the **View knowledge base** permission to the roles that should have access (add it to "Non member" as well if the knowledge base should be visible to users without project membership).

### Docker / docker-compose

If Redmine runs in Docker, clone the plugin into the volume/bind mount that maps to the container's `plugins` directory, then run the migration inside the container:

```bash
docker compose exec redmine bundle exec rake redmine:plugins:migrate NAME=redmine_knowledge_base RAILS_ENV=production
docker compose restart redmine
```

## Uninstallation

```bash
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_knowledge_base VERSION=0
rm -rf plugins/redmine_knowledge_base
```

Then restart Redmine.

## Upgrading

```bash
cd plugins/redmine_knowledge_base
git pull
cd /path/to/redmine
bundle install
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_knowledge_base
```

Restart Redmine after upgrading.

## License

See repository for license details.
