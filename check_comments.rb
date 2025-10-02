# Copyright 2025 Lars Kakavandi-Nielsen (looopTools)
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require 'open3'
require 'optparse'

GIT = 'git'.freeze
STATUS = 'status'.freeze
DIFF = 'diff'.freeze

UNTRACTED_FILES = 'Untracked files:'.freeze

MODIFIED = 'modified:'.freeze

ADD_MODIFIER = '+'.freeze
SUB_MODIFIER = '-'.freeze

def change_line_and_is_comment_line?(line, comment_token)
  (line =~ /^\+[^+]/ || line =~ /^-[^-]/) && !line.empty? && line[1..-1].start_with?(comment_token)
end

def changed_files
  stdout, stderr, status = Open3.capture3("#{GIT} #{STATUS}")

  return nil if status.nil?

  unless stderr.empty?
    puts stderr
    return nil
  end

  lines = stdout.split("\n")

  files = []
  finding_files = false

  lines.each do |line|
    if line.include? MODIFIED
      line = line.gsub(MODIFIED, '').strip
      files.append line
    end
    finding_files = true if line.include? UNTRACTED_FILES

    files.append line.strip if finding_files && !line.include?(UNTRACTED_FILES) && !line.include?('git add') && !line.empty?
  end
  files
end

def diff_file(file_path, comment_token)
  puts "Checking file #{file_path}"
  stdout, stderr, status = Open3.capture3("#{GIT} --no-pager #{DIFF} #{file_path}")

  lines = stdout.split("\n")
  line_count = 1
  comment_lines = 0
  lines.each do |line|
    is_comment_line = change_line_and_is_comment_line?(line, comment_token)
    puts "\t #{line}" if is_comment_line
    comment_lines += 1 if is_comment_line
    line_count += 1
  end

  puts 'No added, changed, or delted comments' if comment_lines.zero?
  puts "Found comment lines added, changed, or deleted: #{comment_lines} out of #{lines.size} lines\n" if !comment_lines.zero?
  puts "-----------------\n"
end


options = {}

OptionParser.new do |opts|
  opts.on('-rREPO', '--repo_path=REPO', 'Path to git respository') { |v| options[:repo] = v }
  opts.on('-cTOKEN', '--comment_token=TOKEN', 'Token used to identify comments') { |v| options[:token] = v }
end.parse!

if !options.key?(:repo)
  puts 'You must provide a path to a repo'
  return
end

if !Dir.exists?(options[:repo])
  puts "#{options[:repo]} is not a directory"
  return
end

if !Dir.exists?("#{options[:repo]}/.git")
  puts "#{options[:repo]} is not a git repository"
  return
end

if !options.key?(:token)
  puts 'You must provide a comment token to identify comments'
  return
end

Dir.chdir(options[:repo])

puts("Checking #{options[:repo]} for add, altered, or deleted comments")

files = changed_files

puts "Number of files changed: #{files.size}"
puts "-----------------\n"
puts "-----------------\n\n"
files.each do |file|
  diff_file(file, options[:token])
end

puts "-----------------\n"
puts "|       DONE    |"
puts "-----------------\n\n"
