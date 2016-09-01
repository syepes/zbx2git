require 'logger'
require 'json'
require 'fileutils'
require "zabbixapi"
require 'git'

$logger = Logger.new('zbx2git.log', 'monthly')
$logger.level = Logger::WARN


def secs2human(secs)
  [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{|count, name|
    if secs > 0
      secs, n = secs.divmod(count)
      "#{n.to_i} #{name}"
    end
  }.compact.reverse.join(' ')
end

def exportConfig(inst, zbx, cfg)
  begin
    ts_s = Time.now.to_i
    $logger.warn "Start Exporting: #{cfg[:type]} (#{inst})"

    results = zbx.query(
      :method => cfg[:method],
      :params => {:output => cfg[:output], :sortorder => cfg[:sortorder]}
    )

    path = "#{Dir.pwd()}/#{inst}/#{cfg[:type]}"
    for result in results do
      begin
        # File name normalization
        file = "#{result["name"].gsub(/[^a-zA-Z0-9\-_\s\.\(\)]/,'')}.json"
        $logger.debug "#{path}/#{file}"

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
        $logger.error "Exporting: #{cfg[:type]} (#{inst}) : #{e.message}"
        $logger.debug "Trace: #{e.backtrace.inspect}"
      end
    end

    begin
      if !File.exists?("#{path}/.git")
        g = Git.init(path, :log => $logger)
        g.add(:all=>true)
        m = g.commit_all('Initial')
        $logger.info "Git (Init): #{m}" if m != nil
      else
        g = Git.open(path, :log => $logger)
        g.add(:all=>true)
        m = g.commit_all('Change') if !g.status.changed.empty?
        $logger.info "Git (Change): #{m}" if m != nil
      end
    rescue Exception => e
       $logger.error "Saving changes to git: #{cfg[:type]} (#{inst}) : #{e.message}"
    end

    $logger.warn "Finished Exporting: #{cfg[:type]} (#{inst}) in #{secs2human(Time.now.to_i - ts_s)}"
  rescue Exception => e
    $logger.error "Exporting: #{cfg[:type]} (#{inst}) : #{e.message}"
    $logger.debug "Trace: #{e.backtrace.inspect}"
  end
end





begin
  cfg = JSON.parse(File.read('zbx2git.json'), :symbolize_names => true)
rescue Exception => e
  $logger.error "Loading config file: zbx2git.json : #{e.message}"
  $logger.debug "Trace: #{e.backtrace.inspect}"
  exit 1
end

for zab_cfg in cfg[:zabbix_cfg] do
  begin
     ts_s = Time.now.to_i
     $logger.warn "Start Collecting: #{zab_cfg[:inst]}"
     zbx = ZabbixApi.connect(:url => zab_cfg[:url], :user => zab_cfg[:user], :password => zab_cfg[:password])

     for exp_cfg in cfg[:export_cfg] do
       exportConfig(zab_cfg[:inst], zbx, exp_cfg)
     end
     $logger.warn "Finished Collecting: #{zab_cfg[:inst]} in #{secs2human(Time.now.to_i - ts_s)}"

  rescue Exception => e
    $logger.error "Connecting to Zabbix: #{zab_cfg[:inst]} : #{e.message}"
    $logger.debug "Trace: #{e.backtrace.inspect}"
  end
end

