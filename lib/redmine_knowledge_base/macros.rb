# frozen_string_literal: true

module RedmineKnowledgeBase
  # Wrapped in a module (rather than calling Macros.register at the file's
  # top level) purely so this file satisfies Zeitwerk's autoloading
  # convention - lib/ is an eager-loaded path, and Zeitwerk expects every
  # file under it to define the constant matching its path
  # (RedmineKnowledgeBase::Macros for lib/redmine_knowledge_base/macros.rb).
  # The actual registration below still runs once, as a side effect of the
  # module body being evaluated when init.rb requires this file.
  module Macros
    # {{kb_synced(slug)}} - the block editor writes this for a "synced
    # block": content lives in a KbSyncedBlock record, not in the article's
    # own Markdown, so editing it once (via KbSyncedBlocksController)
    # updates every article that references the same slug the next time
    # each is rendered.
    Redmine::WikiFormatting::Macros.register do
      desc 'Renders a knowledge base synced block\'s shared content by its slug.' \
           "\n\n{{kb_synced(onboarding-checklist)}}"
      macro :kb_synced do |_obj, args|
        slug = args.first.to_s.strip
        block = KbSyncedBlock.find_by(slug: slug)
        next content_tag('em', "Synced block \"#{slug}\" not found.") if block.nil?

        content_tag('div', textilizable(block.content), class: 'kb-synced-block')
      end
    end
  end
end
