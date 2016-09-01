require 'logger'
require 'fileutils'
require "zabbixapi"
require 'git'

$logger = Logger.new('zbx2git.log', 'weekly')
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
        file = "#{result["name"]}.json".gsub(/[^a-zA-Z0-9\-_\s\.\(\)]/,"")
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
        $logger.error "Error Exporting: #{cfg[:type]} (#{inst}) : #{e.message}"
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
       $logger.error "Error saving changes to git: #{cfg[:type]} (#{inst}) : #{e.message}"
    end

    $logger.warn "Finished Exporting: #{cfg[:type]} (#{inst}) in #{secs2human(Time.now.to_i - ts_s)}"
  rescue Exception => e
    $logger.error "Error Exporting: #{cfg[:type]} (#{inst}) : #{e.message}"
    $logger.debug "Trace: #{e.backtrace.inspect}"
  end
end


@export_cfg = [{ :type => :hosts,
                 :method => "host.get",
                 :output => ["hostid","name"],
                 :sortorder => "hostid",
                 :id => "hostid"
               },
               { :type => :groups,
                 :method => "hostgroup.get",
                 :output => ["groupid","name"],
                 :sortorder => "groupid",
                 :id => "groupid"
               },
               { :type => :valueMaps,
                 :method => "valuemap.get",
                 :output => ["valuemapid","name"],
                 :sortorder => "valuemapid",
                 :id => "valuemapid"
               },
               { :type => :templates,
                 :method => "template.get",
                 :output => ["templateid","name"],
                 :sortorder => "templateid",
                 :id => "templateid"
               },
               { :type => :images,
                 :method => "image.get",
                 :output => ["imageids","name"],
                 :sortorder => "imageids",
                 :id => "imageids"
               },
               { :type => :maps,
                 :method => "map.get",
                 :output => ["sysmapids","name"],
                 :sortorder => "sysmapids",
                 :id => "sysmapids"
               },
               { :type => :screens,
                 :method => "screen.get",
                 :output => ["screenids","name"],
                 :sortorder => "screenids",
                 :id => "screenids"
               }
              ]

@zabbix_cfg = [{ :inst => "PDC-LAB",
                 :url => "http://localhost/api_jsonrpc.php",
                 :user => "Admin",
                 :password => "zabbix",
               }]

for zab_cfg in @zabbix_cfg do
  begin
     ts_s = Time.now.to_i
     $logger.warn "Start Collecting: #{zab_cfg[:inst]}"
     zbx = ZabbixApi.connect(:url => zab_cfg[:url], :user => zab_cfg[:user], :password => zab_cfg[:password])

     for exp_cfg in @export_cfg do
       exportConfig(zab_cfg[:inst], zbx, exp_cfg)
     end
     $logger.warn "Finished Collecting: #{zab_cfg[:inst]} in #{secs2human(Time.now.to_i - ts_s)}"

  rescue Exception => e
    $logger.error "Error Connecting to Zabbix: #{zab_cfg[:inst]} : #{e.message}"
    $logger.debug "Trace: #{e.backtrace.inspect}"
  end
end

