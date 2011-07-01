#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'

module Shell
  def sh command
    system(command) or raise "Command failed with status #{$?.exitstatus}: [#{command}]"
  end
end

class Bridge
  include FileUtils
  include Shell

  def initialize(opts)
    @opts = opts
    @scm = RTC.new(opts[:rtc])
  end

  def init
    File.exists? directory and rm_r directory
    mkdir directory
    cd directory do
      @scm.make_working_copy
      sh "hg init"
      push_change 'Initial bridge checkin.'
    end
  end

  def run
    cd directory do
      logs = @scm.get_logs
      logs.each do |log|
        puts "Syncing #{log.revision}"
        @scm.change_working_copy_to_revision(log.revision)
        push_change '#{log.revision}: #{log.message}'
      end
    end
  end

  private
  def push_change(message)
    sh "hg addremove --quiet --exclude .jazz5 --exclude .metadata"
    sh "hg commit -m '#{message}' -ubridge"
    sh "hg push --quiet #{hg_repo}"
  end

  def directory() @opts[:directory] end
  def hg_repo() @opts[:hg][:repo] end
end

class RTC
  include Shell

  def initialize(opts)
    @opts = opts
  end

  USER = 'ben'
  PASSWORD = 'ben'
  STREAM = "'BRM Stream'"
  WORKSPACE = 'bridge-workspace-8'

  def make_working_copy
    sh "scm create workspace --username #{USER} --password #{PASSWORD} \
          --repository-uri #{repo} --stream #{STREAM} #{workspace}"
    sh "scm load --username #{USER} --password #{PASSWORD} #{workspace}@#{repo}"
  end

  def get_logs
    `scm compare ws #{workspace} stream #{STREAM} --password #{PASSWORD} --include-types s`.
      lines.map { |line| Log.new(line) }
  end

  def change_working_copy_to_revision(revision)
    sh "scm accept --password #{PASSWORD} --changes #{revision}"
  end

  private
  def repo() @opts[:repo] end
  def workspace() @opts[:workspace] end

  class Log
    attr_reader :revision, :message

    def initialize(line)
      parse = /\(([0-9]+)\) (.*)/.match(line)
      @revision = parse[1]
      @message = parse[2]
    end
  end
end

if __FILE__ == $0
  action = nil
  options = {:hg=>{}, :rtc=>{}}

  optparse = OptionParser.new do|opts|
    opts.banner = "Usage: #{$0} [--init | --run] [parameters]"
    opts.separator ''
    opts.separator 'Actions:'
    opts.separator '  give one'

    opts.on('-i', '--init', 'Initialize the bridge') do
      action = :init
    end
    opts.on('-r', '--run', 'Run the bridge') do
      action = :run
    end

    opts.separator ''
    opts.separator 'Parameters:'
    opts.separator '  all mandatory'

    opts.on('-d', '--directory DIRECTORY', 'Working directory',
            '  created or emptied on initialization', '  do not delete between runs') do |dir|
      options[:directory] = dir
    end

    opts.on('-m', '--mercurial-repository REPOSITORY', 'URL of Mercurial repository') do |repo|
      options[:hg][:repo] = repo
    end

    opts.on('-t', '--rtc-repository REPOSITORY', 'URL of RTC SCM repository') do |repo|
      options[:rtc][:repo] = repo
    end

    opts.on('-w', '--rtc-workspace WORKSPACE', 'Workspace to use in RTC repository',
            '  created during initialization') do |ws|
      options[:rtc][:workspace] = ws
    end

    opts.separator ''
    opts.separator 'Other:'
    opts.on( '-h', '--help', 'Display this help' ) do
      puts opts
      exit
    end
  end

  optparse.parse(ARGV)

  unless action
    puts opts
    exit 1
  end

  Bridge.new(options).send(action)
end
