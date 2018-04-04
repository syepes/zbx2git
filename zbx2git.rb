#!/usr/bin/env jruby
#
# DESCRIPTION:
#   Exports your Zabbix configuration and uses Git to store any changes made from the previous runs
#
#
# LICENSE:
#   Copyright 2016 Sebastian YEPES <syepes@gmail.com>
#   Released under the Apache License, see LICENSE for details.
#
require 'logger'
require 'json'
require 'parallel'
require 'fileutils'
require "zabbixapi"
require 'git'
require 'openssl'


def secs2human(secs)
  [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{|count, name|
    if secs > 0
      secs, n = secs.divmod(count)
      "#{n.to_i} #{name}"
    end
  }.compact.reverse.join(' ')
end

def exportConfig(logger, inst, zbx, cfg)
  begin
    ts_s = Time.now.to_i
    path = "#{Dir.pwd()}/repository/#{inst}/#{cfg[:type]}"
    logger.info "Start Exporting: #{cfg[:type]} (#{inst})"

    results = zbx.query(
      :method => cfg[:method],
      :params => {:output => cfg[:output], :sortorder => cfg[:sortorder]}
    )

    # Clean previously exported files
    FileUtils.rm_f(Dir.glob("#{path}/*"))

    for result in results do
      begin
        # File name normalization
        file = "#{result["name"].gsub(/[^a-zA-Z0-9\-_\s\.\(\)]/,'')}.json"
        logger.debug "#{path}/#{file}"

        json = JSON.parse(zbx.query(
          :method => "configuration.export",
          :params => {
            :options => {
              cfg[:type] => [ result[cfg[:id]] ],
            },
            :format => 'json'
          }
        ))

        # Clear export date to prevent unnecessary git changes
        json["zabbix_export"]["date"] = ""
        json_pretty = JSON.pretty_generate(json)

        FileUtils.mkdir_p(path) unless File.exists?(path)
        File.open("#{path}/#{file}","w"){|f| f.puts json_pretty}
      rescue Exception => e
        logger.error "Exporting: #{cfg[:type]} (#{inst}) : #{e.message}"
        logger.debug "Trace: #{e.backtrace.inspect}"
      end
    end

    begin
      if !File.exists?("#{path}/.git")
        g = Git.init(path, :log => logger)
        g.add(:all=>true)
        m = g.commit_all('initial')
        logger.debug "Git (Init): #{m}" if m != nil
        File.open("#{path}/.git/description","w"){|f| f.puts "#{inst} - #{cfg[:type]}"}
      else
        g = Git.open(path, :log => $logger)
        g.add(:all=>true)

        any_change = ["changed","added","deleted"].map{|x| x if !g.status.send(x.to_sym).empty?}.compact.delete_if(&:empty?)
        if !any_change.empty?
          logger.warn "Detected changes: (#{any_change.join(', ')}) in #{cfg[:type]} (#{inst})"
        end

        m = g.commit_all("#{any_change.join(', ')}") if !any_change.empty?
        logger.debug "Git (#{any_change.join(', ')}): #{m}" if m != nil
      end
    rescue Exception => e
       logger.error "Saving changes to git: #{cfg[:type]} (#{inst}) : #{e.message}"
    end

    logger.info "Finished Exporting: #{cfg[:type]} (#{inst}) in #{secs2human(Time.now.to_i - ts_s)}"
  rescue Exception => e
    logger.error "Exporting: #{cfg[:type]} (#{inst}) : #{e.message}"
    logger.debug "Trace: #{e.backtrace.inspect}"
  end
end




FileUtils.mkdir_p("#{Dir.pwd()}/logs") unless File.exists?("#{Dir.pwd()}/logs")
log = Logger.new("logs/zbx2git.log", 'monthly')
log.level = Logger::INFO

begin
  cfg = JSON.parse(File.read('zbx2git.json'), :symbolize_names => true)
rescue Exception => e
  log.error "Error Loading config file: zbx2git.json : #{e.message}"
  log.debug "Trace: #{e.backtrace.inspect}"
  exit 1
end


log.info "Start Collecting of instances: #{cfg[:zabbix_cfg].map{|i| i[:inst] }.join(', ')}"

ts_s = Time.now.to_i
Parallel.each(cfg[:zabbix_cfg], in_threads: 5) { |zab_cfg|
  logger = Logger.new("logs/zbx2git_#{zab_cfg[:inst]}.log", 'monthly')
  logger.level = Logger::INFO

  begin
    ts_s = Time.now.to_i
    logger.info "Start Collecting: #{zab_cfg[:inst]} - #{zab_cfg[:url]}"
    zbx = ZabbixApi.connect(:url => zab_cfg[:url], :user => zab_cfg[:user], :password => zab_cfg[:password], :timeout => 15)

    for exp_cfg in cfg[:export_cfg] do
      exportConfig(logger, zab_cfg[:inst], zbx, exp_cfg)
    end
    logger.info "Finished Collecting: #{zab_cfg[:inst]} in #{secs2human(Time.now.to_i - ts_s)}"

  rescue Exception => e
    logger.error "Connecting to Zabbix: #{zab_cfg[:inst]} : #{e.message}"
    logger.debug "Trace: #{e.backtrace.inspect}"
  end
}
log.info "Completed in #{secs2human(Time.now.to_i - ts_s)}"

