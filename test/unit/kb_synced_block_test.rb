# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class KbSyncedBlockTest < ActiveSupport::TestCase
  def test_valid_slug_is_accepted
    block = KbSyncedBlock.new(slug: 'onboarding-checklist_v2', content: 'Hello')
    assert block.valid?
  end

  def test_slug_with_spaces_is_rejected
    block = KbSyncedBlock.new(slug: 'not a valid slug', content: 'Hello')
    refute block.valid?
    assert_includes block.errors[:slug], 'may only contain letters, numbers, hyphens and underscores'
  end

  def test_slug_must_be_unique
    KbSyncedBlock.create!(slug: 'shared-note', content: 'First')
    dup = KbSyncedBlock.new(slug: 'shared-note', content: 'Second')
    refute dup.valid?
  end
end
