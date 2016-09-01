require "zabbixapi"

def exportTemplates(zbx)
   templates = zbx.query(
       :method => "template.get",
       :params => {:output => ["templateid","name"], :sortorder => "templateid"}
   )

   for template in templates do
      #puts JSON.pretty_generate(template)
      printf "Filename : '%s/%s'\n", Dir.pwd(), template["name"]+".json"

      json = JSON.parse(zbx.query(
          :method => "configuration.export",
          :params => {
            :options => {
              :templates => [ template["templateid"] ],
            },
            :format => 'json'
          }
      ))

      json_pretty = JSON.pretty_generate(json)
      Dir.mkdir(Dir.pwd()+"/templates") unless File.exists?(Dir.pwd()+"/templates")
      File.open("templates/"+template["name"]+".json","w"){|file| file.puts json_pretty}
   end
end

def exportValueMaps(zbx)
   valuemaps = zbx.query(
       :method => "valuemap.get",
       :params => {:output => ["valuemapid","name"], :sortorder => "valuemapid"}
   )

   for valuemap in valuemaps do
      #puts JSON.pretty_generate(valuemap)
      printf "Filename : '%s/%s'\n", Dir.pwd(), valuemap["name"]+".json"

      json = JSON.parse(zbx.query(
          :method => "configuration.export",
          :params => {
            :options => {
              :valueMaps => [ valuemap["valuemapid"] ],
            },
            :format => 'json'
          }
      ))

      json_pretty = JSON.pretty_generate(json)
      #File.open(valuemap["name"]+".json","w"){|file| file.puts json_pretty}
   end
end

def exportGroups(zbx)
   groups = zbx.query(
       :method => "hostgroup.get",
       :params => {:output => ["groupid","name"], :sortorder => "groupid"}
   )

   for group in groups do
      #puts JSON.pretty_generate(group)
      printf "Filename : '%s/%s'\n", Dir.pwd(), group["name"]+".json"

      json = JSON.parse(zbx.query(
          :method => "configuration.export",
          :params => {
            :options => {
              :groups => [ group["groupid"] ],
            },
            :format => 'json'
          }
      ))

      json_pretty = JSON.pretty_generate(json)
      File.open(group["name"]+".json","w"){|file| file.puts json_pretty}
   end
end

def exportHosts(zbx)
   hosts = zbx.query(
       :method => "host.get",
       :params => {:output => ["hostid","name"], :sortorder => "hostid"}
   )

   for host in hosts do
      #puts JSON.pretty_generate(host)
      printf "Filename : '%s/%s'\n", Dir.pwd(), host["name"]+".json"

      json = JSON.parse(zbx.query(
          :method => "configuration.export",
          :params => {
            :options => {
              :hosts => [ host["hostid"] ],
            },
            :format => 'json'
          }
      ))

      json_pretty = JSON.pretty_generate(json)
      File.open(host["name"]+".json","w"){|file| file.puts json_pretty}
   end
end

zbx = ZabbixApi.connect(
  :url => 'http://localhost/api_jsonrpc.php',
  :user => 'Admin',
  :password => 'zabbix'
)

exportTemplates(zbx)
exportValueMaps(zbx)
exportGroups(zbx)
exportHosts(zbx)
