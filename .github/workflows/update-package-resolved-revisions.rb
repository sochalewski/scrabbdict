#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"

ROOT = File.expand_path("../..", __dir__)
PACKAGE_RESOLVED = File.join(
  ROOT,
  "Scrabbdict.xcodeproj",
  "project.xcworkspace",
  "xcshareddata",
  "swiftpm",
  "Package.resolved"
)
PACKAGE_RESOLVED_RELATIVE = "Scrabbdict.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

base_ref = ARGV.fetch(0) do
  warn "usage: #{$PROGRAM_NAME} <base-git-ref>"
  exit 2
end

current_text = File.read(PACKAGE_RESOLVED)
current = JSON.parse(current_text)

base_text, status = Open3.capture2("git", "show", "#{base_ref}:#{PACKAGE_RESOLVED_RELATIVE}", chdir: ROOT)
unless status.success?
  warn "error: could not read #{PACKAGE_RESOLVED_RELATIVE} from #{base_ref}"
  exit 1
end

base_versions = JSON.parse(base_text).fetch("pins").to_h do |pin|
  [pin.fetch("identity"), pin.dig("state", "version")]
end

def resolve_tag_revision(location, version)
  ["#{version}", "v#{version}"].uniq.each do |tag|
    output, status = Open3.capture2(
      "git",
      "ls-remote",
      "--tags",
      location,
      "refs/tags/#{tag}",
      "refs/tags/#{tag}^{}"
    )
    next unless status.success?

    refs = output.lines.filter_map do |line|
      sha, ref = line.split
      [ref, sha] if sha && ref
    end.to_h

    return refs["refs/tags/#{tag}^{}"] || refs["refs/tags/#{tag}"]
  end

  nil
end

updated_text = current_text.dup
updated_count = 0

current.fetch("pins").each do |pin|
  identity = pin.fetch("identity")
  state = pin.fetch("state")
  version = state["version"]
  next unless version
  next if base_versions[identity] == version

  location = pin.fetch("location")
  revision = resolve_tag_revision(location, version)
  unless revision
    warn "error: could not resolve #{identity} #{version} from #{location}"
    exit 1
  end

  pattern = /
    (
      "identity"\s:\s"#{Regexp.escape(identity)}",\s+
      "kind"\s:\s"remoteSourceControl",\s+
      "location"\s:\s"#{Regexp.escape(location)}",\s+
      "state"\s:\s\{\s+
      "revision"\s:\s"
    )
    [a-f0-9]+
    (
      ",\s+
      "version"\s:\s"#{Regexp.escape(version)}"
    )
  /x

  replaced = false
  updated_text = updated_text.sub(pattern) do
    replaced = true
    "#{Regexp.last_match(1)}#{revision}#{Regexp.last_match(2)}"
  end

  unless replaced
    warn "error: could not update revision for #{identity} #{version} in #{PACKAGE_RESOLVED_RELATIVE}"
    exit 1
  end

  updated_count += 1
  puts "Updated #{identity} #{version} revision to #{revision}"
end

if updated_count.positive?
  File.write(PACKAGE_RESOLVED, updated_text)
else
  puts "No Package.resolved version changes detected"
end
