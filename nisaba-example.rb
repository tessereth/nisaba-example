#!/usr/bin/env ruby

require 'bundler/setup'
require 'nisaba'

Nisaba.configure do |n|
  n.api_token = ENV['API_TOKEN']
  n.webhook_secret = ENV['WEBHOOK_SCRET']

  n.label 'migration' do |pr|
    pr.file?(%r{db/migrate/.*})
  end

  n.label 'style' do |pr|
    pr.file?(/.*\.scss/)
  end

  KNOWN_CONTRIBUTORS = %w[tessereth]

  n.label 'outside contributor' do |pr|
    !KNOWN_CONTRIBUTORS.include?(pr.author)
  end

  GENERATED_FILES = %w[db/data.sql Gemfile.lock yarn.lock]

  n.comment 'non-generated diff count' do |c|
    c.when do |pr|
      GENERATED_FILES.any? { |f| pr.file?(f) }
    end

    c.body do |pr|
      added = 0
      removed = 0
      pr.diff.each do |filename, changes|
        next if GENERATED_FILES.include?(filename)

        added += changes.added_count
        removed += changes.removed_count
      end

      "Diff ignoring generated files: +#{added} -#{removed}"
    end

    c.update_strategy :edit # or :replace
  end

  n.review 'remove column' do |c|
    c.when do |pr|
      pr.diff.each do |filename, changes|
        next unless filename.match?(%r{db/migrate/.*}) && changes.added?(/remove_column/)
      end
    end

    c.body do
      "I noticed you're dropping a column. Did you double check it's been added to ignored_columns in a separate PR?" +
        "\n\nSee https://github.com/ankane/strong_migrations#removing-a-column for more details"
    end

    c.line_comments do |pr|
      comments = []
      pr.diff.each do |filename, changes|
        next unless filename.match?(%r{db/migrate/.*})
        changes.added.each do |added, position|
          next unless added.match?(/remove_column/)
          comments << { path: filename, position: position, body: 'Column removed here'}
        end
      end
      comments
    end

    c.type :comment
  end
end

Nisaba.run!
