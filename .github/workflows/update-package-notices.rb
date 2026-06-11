#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

ROOT = File.expand_path("../..", __dir__)
PACKAGE_RESOLVED = File.join(
  ROOT,
  "Scrabbdict.xcodeproj",
  "project.xcworkspace",
  "xcshareddata",
  "swiftpm",
  "Package.resolved"
)
ROOT_PLIST = File.join(
  ROOT,
  "Scrabbdict",
  "Resources",
  "Settings.bundle",
  "Root.plist"
)

resolved = JSON.parse(File.read(PACKAGE_RESOLVED))
versions = resolved.fetch("pins").each_with_object({}) do |pin, result|
  version = pin.dig("state", "version")
  result[pin.fetch("identity")] = version if version
end

plist = File.read(ROOT_PLIST)
updated = plist.gsub(/^(- ([a-z0-9._+-]+) )([0-9A-Za-z._+-]+)(.*)$/) do
  prefix = Regexp.last_match(1)
  identity = Regexp.last_match(2)
  suffix = Regexp.last_match(4)
  version = versions[identity]

  version ? "#{prefix}#{version}#{suffix}" : Regexp.last_match(0)
end

if updated != plist
  File.write(ROOT_PLIST, updated)
  puts "Updated package versions in #{ROOT_PLIST}"
else
  puts "Package notices already match #{PACKAGE_RESOLVED}"
end
