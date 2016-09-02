zbx2git + cgit + uwsgi + nginx
================
These instructions are specific to CentOS 7 but should be a guideline for other distros
---

#### OS Deps
    yum -y install git nginx unzip openssl-devel


#### Install cgit
    cd /tmp/
    curl -#SL https://git.zx2c4.com/cgit/snapshot/cgit-1.0.zip | unzip
    cd cgit-1.0
    make get-git
    make NO_LUA=1
    cp cgit /usr/sbin/
    mkdir -p /usr/share/cgit/
    cp cgit.css /usr/share/cgit/
    curl -#SL http://www.zabbix.com/favicon.ico -o /usr/share/cgit/favicon.ico
    curl -#SL http://www.zabbix.com/img/zabbix_logo.png -o /usr/share/cgit/cgit.png
    mkdir -p /var/cache/cgit
    chown uwsgi:uwsgi /var/cache/cgit


#### Install+Setup uwsgi
    cd /tmp/
    curl http://uwsgi.it/install | bash -s cgi /usr/sbin/uwsgi

    cat >/etc/uwsgi.ini <<EOF
    [uwsgi]
    master = true
    plugin = cgi
    socket = /run/uwsgi/cgit.sock
    uid = uwsgi
    gid = uwsgi
    processes = 1
    threads = 2
    cgi = /usr/sbin/cgit
    EOF

    cat >/etc/systemd/system/uwsgi.service <<EOF
    [Unit]
    Description=uWSGI Emperor Service
    After=network.target
    After=syslog.target

    [Service]
    EnvironmentFile=-/etc/sysconfig/uwsgi
    ExecStartPre=/bin/mkdir -p /run/uwsgi
    ExecStartPost=/bin/chown -R uwsgi:uwsgi /run/uwsgi
    ExecStartPost=/bin/chmod 775 /run/uwsgi/cgit.sock
    ExecStart=/usr/sbin/uwsgi --ini /etc/uwsgi.ini
    ExecReload=/bin/kill -HUP $MAINPID
    KillSignal=SIGINT
    Restart=always
    Type=notify
    NotifyAccess=all

    [Install]
    WantedBy=multi-user.target
    EOF


#### Config nginx
    # Add the following lines to your current config 
    vi /etc/nginx/nginx.conf
    server {
            location ~* ^.+(cgit.(css|png)|favicon.ico|robots.txt) {
                 root /usr/share/cgit/;
                 expires 30d;
            }
            location / {
              include uwsgi_params;
              uwsgi_modifier1 9;
              uwsgi_pass unix:/run/uwsgi/cgit.sock;
            }
    }


#### Start uwsgi & nginx

    systemctl daemon-reload
    systemctl enable uwsgi.service nginx.service
    systemctl start uwsgi.service nginx.service

