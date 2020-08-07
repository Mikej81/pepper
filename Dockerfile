#FROM registry.access.redhat.com/ubi8/ubi:8.1
FROM centos:7

ENV container docker

ARG nginxVer=1.16.1
ARG home=/usr/src

WORKDIR /usr/src

RUN yum update -y \
    && yum install epel-release -y \
    && yum groupinstall 'Development Tools' -y \
    && yum group mark install "Development Tools" \
    && yum group update "Development Tools" -y \
    && yum update -y \
    && yum install nginx -y\
    && yum install gcc-c++ flex bison yajl yajl-devel curl-devel curl GeoIP-devel doxygen zlib-devel wget openssl-devel -y \
    && yum install lmdb lmdb-devel libxml2 libxml2-devel ssdeep ssdeep-devel lua lua-devel pcre-devel libxslt-devel curl -y \
    && yum install gd gd-devel perl-ExtUtils-Embed gperftools-devel yum-utils -y \
    && mkdir /etc/nginx/modsec \
    && wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended \
    && mv /etc/nginx/modsec/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf \
    && git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity \
    && cd ${home}/ModSecurity \ 
    && git submodule init \
    && git submodule update \
    && ./build.sh \
    && ./configure \
    && make \
    && make install \
    && cd ${home} \
    && git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git \
    && wget http://nginx.org/download/nginx-${nginxVer}.tar.gz \
    && tar zxvf nginx-${nginxVer}.tar.gz \
    && cd ./nginx-${nginxVer}\
    && ./configure --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log \
      --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy \
      --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi \
      --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx \
      --user=nginx --group=nginx --with-file-aio --with-http_ssl_module --with-http_v2_module --with-http_realip_module \
      --with-stream_ssl_preread_module --with-http_addition_module --with-http_xslt_module=dynamic \
      --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module \
      --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module \
      --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module \
      --with-http_perl_module=dynamic --with-http_auth_request_module --with-mail=dynamic --with-mail_ssl_module --with-pcre \
      --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-google_perftools_module --with-debug \
      --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -m64 -mtune=generic' \
      --with-ld-opt='-Wl,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E' --with-http_geoip_module \
      --add-dynamic-module=../ModSecurity-nginx \
    && make modules \
    && mv objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/ \
    && mv /usr/src/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsecurity.conf \
    && mv /usr/src/ModSecurity/unicode.mapping /etc/nginx/unicode.mapping \
    && cd ${home} \
    && git clone https://github.com/coreruleset/coreruleset.git \
    && mv coreruleset/rules/ /etc/nginx/modsec/ \
    && mv coreruleset/crs-setup.conf.example /etc/nginx/modsec/crs-setup.conf \
    && mv /etc/nginx/modsec/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example /etc/nginx/modsec/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf \
    && sed -i '/pid \/run\/nginx.pid;/a   load_module modules\/ngx_http_modsecurity_module.so;\' /etc/nginx/nginx.conf \
    && sed -i '/server {/a     modsecurity on;' /etc/nginx/nginx.conf \
    && sed -i '/include \/etc\/nginx\/default.d/*.conf;/a     modsecurity_rules_file \/etc\/nginx\/modsec_includes.conf;' /etc/nginx/nginx.conf \
    && yum --disableplugin=subscription-manager clean all -y \
    && rm -rf /var/cache/yum \
    && rm -rf /var/tmp/yum-* \
    && yum remove `package-cleanup --quiet --leaves` -y \
    && package-cleanup --oldkernels --count=1

EXPOSE 80 443
#USER 1001

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
#CMD ["bash"]