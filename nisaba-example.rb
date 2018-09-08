#!/usr/bin/env ruby

require 'bundler/setup'
require 'nisaba'

Nisaba.configure do |n|
  n.app_id = ENV['GITHUB_APP_IDENTIFIER']
  n.app_private_key = ENV['GITHUB_PRIVATE_KEY'].gsub('\n', "\n")
  n.webhook_secret = ENV['GITHUB_WEBHOOK_SECRET']

  n.label 'style' do |context|
    context.file?(/.*\.scss/)
  end

  n.label 'dependencies' do |context|
    context.file?('Gemfile.lock')
  end

  KNOWN_CONTRIBUTORS = %w[tessereth]

  n.label 'outside contributor' do |context|
    !KNOWN_CONTRIBUTORS.include?(context.payload.dig(:pull_request, :user, :login))
  end

  GENERATED_FILES = %w[db/data.sql Gemfile.lock yarn.lock]

  n.comment 'non-generated diff count' do |c|
    c.when do |context|
      GENERATED_FILES.any? { |f| context.file?(f) }
    end

    c.body do |context|
      added = 0
      removed = 0
      context.diff.files.each do |file|
        next if GENERATED_FILES.include?(file.a_path) || GENERATED_FILES.include?(file.b_path)

        # if you add an empty file, number_of_* are nil
        added += file.stats.number_of_additions || 0
        removed += file.stats.number_of_deletions || 0
      end

      "Diff ignoring generated files: +#{added} -#{removed}"
    end

    c.update_strategy = :edit # or :replace
  end

  n.review 'remove column' do |c|
    c.when do |context|
      context.diff.files.each do |file|
        next unless file.a_path.match?(%r{db/migrate/.*})
        file.hunks.each do |hunk|
          hunk.lines.each do |line|
            if line.addition? && line.content.include?('remove_column')
              return true
            end
          end
        end
      end
      return false
    end

    c.body do
      "I noticed you're dropping a column. Did you double check it's been added to ignored_columns in a separate PR?" +
        "\n\nSee https://github.com/ankane/strong_migrations#removing-a-column for more details"
    end

    # TODO: figure out how to do line comments. Maybe something like this?
    c.line_comments do |context|
      comments = []
      context.each_diff_line do |filename, line, position|
        next unless filename.match?(%r{db/migrate/.*})
        next unless line.content.include?('remove_column')
        comments << { path: filename, position: position, body: 'Column removed here'}
      end
      comments
    end

    c.type = :comment
  end
end

Nisaba.run!
