# Usage:
#
# docker build --force-rm -t zbx2git .
# docker run -it --rm -h zbx2git -v /opt/zbx2git/zbx2git.json:/opt/zbx2git/zbx2git.json -v /opt/zbx2git/repository:/opt/zbx2git/repository -v /opt/zbx2git/logs:/opt/zbx2git/logs zbx2git
#
FROM        ruby:alpine
MAINTAINER  Sebastian YEPES <syepes@gmail.com>

ARG         APK_FLAGS_COMMON="-q"
ARG         APK_FLAGS_PERSISTANT="${APK_FLAGS_COMMON} --clean-protected --no-cache"
ARG         APK_FLAGS_DEV="${APK_FLAGS_COMMON} --no-cache"

ENV         LANG=en_US.UTF-8 \
            TERM=xterm

RUN         apk update && apk upgrade \
            && apk add ${APK_FLAGS_PERSISTANT} git \
            && apk add ${APK_FLAGS_DEV} --virtual build-deps build-base curl libffi-dev \
            && mkdir -p /opt/zbx2git/ \
            && curl -#SL "https://raw.githubusercontent.com/syepes/zbx2git/master/zbx2git.rb" > /opt/zbx2git/zbx2git.rb \
            && chmod 755 /opt/zbx2git/zbx2git.rb \
            && gem install parallel zabbixapi git \
            && git config --global user.email "zbx2git@example.com" \
            && git config --global user.name "zbx2git" \
            && sed -i '/.*raise ApiError.new("Zabbix API version:.*/d' /usr/local/bundle/gems/zabbixapi-*/lib/zabbixapi/client.rb \
            && apk del ${APK_FLAGS_COMMON} --purge build-deps \
            && rm -rf /var/cache/apk/* /tmp/*

WORKDIR     /opt/zbx2git/
CMD         ["ruby", "zbx2git.rb"]

