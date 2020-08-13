#FROM registry.access.redhat.com/ubi8/ubi:8.1
FROM centos:7 as base

ARG PLATFORM=opensource
ENV UPSTREAM_SERVER=example.com

ARG nginxVer=1.16.1
ARG home=/usr/src

WORKDIR /usr/src

COPY dockerfile nginx-repo.crt nginx-repo.key ${WORKDIR}/

RUN if [ "$PLATFORM" = "opensource" ] ; then \
      yum update -y \
      && yum install epel-release -y \
      && yum groupinstall 'Development Tools' -y \
      && yum group mark install "Development Tools" \
      && yum group update "Development Tools" -y \
      && yum update -y \
      && yum install nginx -y\
      && yum install gcc-c++ flex bison yajl yajl-devel curl-devel curl GeoIP-devel doxygen zlib-devel wget openssl-devel -y \
      && yum install lmdb lmdb-devel libxml2 libxml2-devel ssdeep ssdeep-devel lua lua-devel pcre-devel libxslt-devel curl -y \
      && yum install gd gd-devel perl-ExtUtils-Embed gperftools-devel yum-utils gunzip -y \
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
      && yum --disableplugin=subscription-manager clean all -y \
      && rm -rf /var/cache/yum \
      && rm -rf /var/tmp/yum-* \
      && yum remove `package-cleanup --quiet --leaves` -y \
      && package-cleanup --oldkernels --count=1; \
    elif [ "$PLATFORM" = "plus"  ] ; then \
      mkdir /etc/ssl/nginx \
      && mv ${WORKDIR}/nginx-repo.* /etc/ssl/nginx/ \
      && yum update -y \
      && yum -y install wget ca-certificates epel-release -y \
      && wget -P /etc/yum.repos.d https://cs.nginx.com/static/files/nginx-plus-7.repo \
      && yum install app-protect -y\
      && yum install nginx-plus-module-modsecurity nginx-plus-module-xslt nginx-plus-module-geoip2 -y \
      && yum install nginx-plus-module-image-filter nginx-plus-module-perl nginx-plus-module-njs -y \
      && yum clean all \
      && rm -rf /etc/cache/yum \
      && rm -rf /etc/ssl/nginx; \
    fi

    FROM base as proxy 

    RUN if [ "$PLATFORM" = "opensource" ] ; then \
      cd ${home} \
      && git clone https://github.com/coreruleset/coreruleset.git \
      && mv coreruleset/rules/ /etc/nginx/modsec/ \
      && mv coreruleset/crs-setup.conf.example /etc/nginx/modsec/crs-setup.conf \
      && mv /etc/nginx/modsec/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example /etc/nginx/modsec/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf \
      && echo -e 'IyBOR0lOWCBTZWN1cmVkIFByb3h5IGluIGEgQm94CiMgTWljaGFlbCBDb2xlbWFuIEAgRjUKCnVzZXIgbmdpbng7Cndvcmtlcl9wcm9jZXNzZXMgYXV0bzsKCmVycm9yX2xvZyAgIC92YXIvbG9nL25naW54L2Vycm9yLmxvZyBub3RpY2U7CnBpZCAgICAgICAgIC9ydW4vbmdpbngucGlkOwoKbG9hZF9tb2R1bGUgbW9kdWxlcy9uZ3hfaHR0cF9tb2RzZWN1cml0eV9tb2R1bGUuc287CiNpbmNsdWRlIC91c3Ivc2hhcmUvbmdpbngvbW9kdWxlcy8qLmNvbmY7CgpldmVudHMgewogICAgd29ya2VyX2Nvbm5lY3Rpb25zICAxMDI0Owp9CgpodHRwIHsKICAgIGluY2x1ZGUgICAgICAgICAgICAgL2V0Yy9uZ2lueC9taW1lLnR5cGVzOwogICAgZGVmYXVsdF90eXBlICAgICAgICBhcHBsaWNhdGlvbi9vY3RldC1zdHJlYW07CgogICAgc2VydmVyX25hbWVzX2hhc2hfYnVja2V0X3NpemUgIDEyODsKCiAgICBsb2dfZm9ybWF0ICBtYWluICAnJHJlbW90ZV9hZGRyIC0gJHJlbW90ZV91c2VyIFskdGltZV9sb2NhbF0gIiRyZXF1ZXN0IiAnCiAgICAgICAgICAgICAgICAgICAgICAnJHN0YXR1cyAkYm9keV9ieXRlc19zZW50ICIkaHR0cF9yZWZlcmVyIiAnCiAgICAgICAgICAgICAgICAgICAgICAnIiRodHRwX3VzZXJfYWdlbnQiICIkaHR0cF94X2ZvcndhcmRlZF9mb3IiJzsKCiAgICBhY2Nlc3NfbG9nICAvdmFyL2xvZy9uZ2lueC9hY2Nlc3MubG9nICBtYWluOwoKICAgIHRjcF9ub2RlbGF5ICAgICAgICAgb247CiAgICBrZWVwYWxpdmVfdGltZW91dCAgIDY1OwogICAgdHlwZXNfaGFzaF9tYXhfc2l6ZSAyMDQ4OwoKICAgIGluY2x1ZGUgL2V0Yy9uZ2lueC9jb25mLmQvKi5jb25mOwoKICAgIHVwc3RyZWFtIGJhY2tlbmQgewogICAgICAgIHNlcnZlciAke1VQU1RSRUFNX1NFUlZFUn0KICAgIH0KCiAgICBzZXJ2ZXIgewogICAgICAgIGxpc3RlbiA4MDsKICAgICAgICBsaXN0ZW4gWzo6XTo4MDsKCiAgICAgICAgc2VydmVyX25hbWUgIF87CgogICAgICAgIG1vZHNlY3VyaXR5IG9uOwogICAgICAgIG1vZHNlY3VyaXR5X3J1bGVzX2ZpbGUgL2V0Yy9uZ2lueC9tb2RzZWNfaW5jbHVkZXMuY29uZjsKCiAgICAgICAgYWNjZXNzX2xvZyAvdmFyL2xvZy9uZ2lueC9hY2Nlc3MubG9nOwogICAgICAgIGVycm9yX2xvZyAgL3Zhci9sb2cvbmdpbngvZXJyb3IubG9nOwoKICAgICAgICAjc3NsX2NlcnRpZmljYXRlICAgICAvZXRjL2xldHNlbmNyeXB0L2xpdmUvJHtwaXBfZG5zfS9mdWxsY2hhaW4ucGVtOwogICAgICAgICNzc2xfY2VydGlmaWNhdGVfa2V5IC9ldGMvbGV0c2VuY3J5cHQvbGl2ZS8ke3BpcF9kbnN9L3ByaXZrZXkucGVtOwoKICAgICAgICAjIFBlcmZlY3QgRm9yd2FyZCBTZWN1cml0eQogICAgICAgIHNzbF9wcm90b2NvbHMgVExTdjEuMjsKICAgICAgICBzc2xfcHJlZmVyX3NlcnZlcl9jaXBoZXJzIG9uOwogICAgICAgIHNzbF9jaXBoZXJzICJFRUNESCtFQ0RTQStBRVNHQ00gRUVDREgrRUNEU0ErU0hBMzg0IEVFQ0RIK0VDRFNBK1NIQTI1NiBFRUNESCAhYU5VTEwgIWVOVUxMICFMT1cgITNERVMgIU1ENSAhRVhQICFQU0sgIVNSUCAhRFNTICFSQzQgIUNCQyI7CiAgICAgICAgc3NsX3N0YXBsaW5nIG9uOwogICAgICAgIHNzbF9zdGFwbGluZ192ZXJpZnkgb247CiAgICAgICAgc3NsX3RydXN0ZWRfY2VydGlmaWNhdGUgL2V0Yy9sZXRzZW5jcnlwdC9saXZlLyR7cGlwX2Ruc30vZnVsbGNoYWluLnBlbTsKICAgICAgICBzc2xfc2Vzc2lvbl9jYWNoZSAgICBzaGFyZWQ6U1NMOjEwbTsKICAgICAgICBzc2xfc2Vzc2lvbl90aW1lb3V0ICAxMG07CgogICAgICAgIGxvY2F0aW9uIC9oZWFsdGggewogICAgICAgICAgICBhY2Nlc3NfbG9nIG9mZjsKICAgICAgICAgICAgYWRkX2hlYWRlciBDb250ZW50LVR5cGUgdGV4dC9wbGFpbjsKICAgICAgICAgICAgcmV0dXJuIDIwMCAnY2hlZXNlYnVyZ2VyIVxuJzsKICAgICAgICB9CgogICAgICAgIGluY2x1ZGUgL2V0Yy9uZ2lueC9kZWZhdWx0LmQvKi5jb25mOwoKICAgICAgICBsb2NhdGlvbiAvIHsKICAgICAgICAgICAgI2FkZF9oZWFkZXIgU3RyaWN0LVRyYW5zcG9ydC1TZWN1cml0eSAibWF4LWFnZT0zMTUzNjAwMDsgaW5jbHVkZVN1YkRvbWFpbnMiIGFsd2F5czsKICAgICAgICAgICAgcHJveHlfcGFzcyBodHRwOi8vYmFja2VuZDsKICAgICAgICAgICAgcHJveHlfaHR0cF92ZXJzaW9uIDEuMTsKICAgICAgICAgICAgcHJveHlfc2V0X2hlYWRlciBVcGdyYWRlICRodHRwX3VwZ3JhZGU7CiAgICAgICAgICAgIHByb3h5X3NldF9oZWFkZXIgQ29ubmVjdGlvbiBrZWVwLWFsaXZlOwogICAgICAgICAgICBwcm94eV9zZXRfaGVhZGVyIEhvc3QgJGhvc3Q7CiAgICAgICAgICAgIHByb3h5X3NldF9oZWFkZXIgICBYLVJlYWwtSVAgICAgICAgICRyZW1vdGVfYWRkcjsKICAgICAgICAgICAgcHJveHlfc2V0X2hlYWRlciAgIFgtRm9yd2FyZGVkLUZvciAgJHByb3h5X2FkZF94X2ZvcndhcmRlZF9mb3I7CiAgICAgICAgICAgIHByb3h5X21heF90ZW1wX2ZpbGVfc2l6ZSAwOwogICAgICAgICAgICBwcm94eV9jb25uZWN0X3RpbWVvdXQgICAgICAyMDsKICAgICAgICAgICAgcHJveHlfc2VuZF90aW1lb3V0ICAgICAgICAgMjA7CiAgICAgICAgICAgIHByb3h5X3JlYWRfdGltZW91dCAgICAgICAgIDkwOwogICAgICAgICAgICBwcm94eV9idWZmZXJfc2l6ZSAgICAgICAgICA0azsKICAgICAgICAgICAgcHJveHlfYnVmZmVycyAgICAgICAgICAgICAgNCAzMms7CiAgICAgICAgICAgIHByb3h5X2J1c3lfYnVmZmVyc19zaXplICAgIDY0azsKICAgICAgICAgICAgcHJveHlfdGVtcF9maWxlX3dyaXRlX3NpemUgNjRrOwogICAgICAgIH0KICAgIH0KfQ==' | base64 -d  > /etc/nginx/nginx.conf \
      && echo -e 'IyBGcm9tIGh0dHBzOi8vZ2l0aHViLmNvbS9TcGlkZXJMYWJzL01vZFNlY3VyaXR5L2Jsb2IvbWFzdGVyLwojIG1vZHNlY3VyaXR5LmNvbmYtcmVjb21tZW5kZWQKIwojIEVkaXQgdG8gc2V0IFNlY1J1bGVFbmdpbmUgT24KSW5jbHVkZSAiL2V0Yy9uZ2lueC9tb2RzZWMvbW9kc2VjdXJpdHkuY29uZiIKCiNJbmNsdWRlIC9ldGMvbmdpbngvbW9kc2VjL2Nycy1zZXR1cC5jb25mCiNJbmNsdWRlIC9ldGMvbmdpbngvbW9kc2VjL3J1bGVzLyouY29uZgojSW5jbHVkZSAvZXRjL25naW54L21vZHNlYy9SRVNQT05TRS05OTktRVhDTFVTSU9OLVJVTEVTLUFGVEVSLUNSUy5jb25mCgojIEJhc2ljIHRlc3QgcnVsZQpTZWNSdWxlIEFSR1M6dGVzdHBhcmFtICJAY29udGFpbnMgdGVzdCIgImlkOjEyMzQsZGVueSxzdGF0dXM6NDAzIg==' | base64 -d > /etc/nginx/modsec_includes.conf; \
    elif [ "$PLATFORM" = "plus"  ] ; then \
      echo -e 'IyBOR0lOWCBTZWN1cmVkIFByb3h5IGluIGEgQm94CiMgTWljaGFlbCBDb2xlbWFuIEAgRjUKCnVzZXIgbmdpbng7Cndvcmtlcl9wcm9jZXNzZXMgYXV0bzsKCmVycm9yX2xvZyAgL3Zhci9sb2cvbmdpbngvZXJyb3IubG9nIG5vdGljZTsKcGlkICAgICAgICAvdmFyL3J1bi9uZ2lueC5waWQ7Cgpsb2FkX21vZHVsZSBtb2R1bGVzL25neF9odHRwX2FwcF9wcm90ZWN0X21vZHVsZS5zbzsKbG9hZF9tb2R1bGUgbW9kdWxlcy9uZ3hfaHR0cF9nZW9pcF9tb2R1bGUuc287CmxvYWRfbW9kdWxlIG1vZHVsZXMvbmd4X3N0cmVhbV9nZW9pcF9tb2R1bGUuc287CgpldmVudHMgewogICAgd29ya2VyX2Nvbm5lY3Rpb25zICAxMDI0Owp9CgpodHRwIHsKICAgIGluY2x1ZGUgICAgICAgL2V0Yy9uZ2lueC9taW1lLnR5cGVzOwogICAgZGVmYXVsdF90eXBlICBhcHBsaWNhdGlvbi9vY3RldC1zdHJlYW07CgogICAgc2VydmVyX25hbWVzX2hhc2hfYnVja2V0X3NpemUgIDEyODsKCiAgICBsb2dfZm9ybWF0ICBtYWluICAnJHJlbW90ZV9hZGRyIC0gJHJlbW90ZV91c2VyIFskdGltZV9sb2NhbF0gIiRyZXF1ZXN0IiAnCiAgICAgICAgICAgICAgICAgICAgICAnJHN0YXR1cyAkYm9keV9ieXRlc19zZW50ICIkaHR0cF9yZWZlcmVyIiAnCiAgICAgICAgICAgICAgICAgICAgICAnIiRodHRwX3VzZXJfYWdlbnQiICIkaHR0cF94X2ZvcndhcmRlZF9mb3IiJzsKCiAgICBhY2Nlc3NfbG9nICAvdmFyL2xvZy9uZ2lueC9hY2Nlc3MubG9nICBtYWluOwoKICAgIHRjcF9ub2RlbGF5ICAgICAgICAgb247CiAgICBrZWVwYWxpdmVfdGltZW91dCAgIDY1OwogICAgdHlwZXNfaGFzaF9tYXhfc2l6ZSAyMDQ4OwoKICAgIHVwc3RyZWFtIGJhY2tlbmQgewogICAgICAgIHNlcnZlciAke1VQU1RSRUFNX1NFUlZFUn0KICAgIH0KCiAgICBzZXJ2ZXIgewogICAgICAgIGxpc3RlbiAgICAgICA4MCBkZWZhdWx0X3NlcnZlcjsKICAgICAgICBsaXN0ZW4gICAgICAgWzo6XTo4MCBkZWZhdWx0X3NlcnZlcjsKCiAgICAgICAgYXBwX3Byb3RlY3RfZW5hYmxlIG9uOwogICAgICAgIGFwcF9wcm90ZWN0X3NlY3VyaXR5X2xvZ19lbmFibGUgb247CiAgICAgICAgYXBwX3Byb3RlY3Rfc2VjdXJpdHlfbG9nICIvZXRjL25naW54L2N1c3RvbV9sb2dfZm9ybWF0Lmpzb24iIHN5c2xvZzpzZXJ2ZXI9MTI3LjAuMC4xOjUxNTsKCiAgICAgICAgc2VydmVyX25hbWUgIF87CgogICAgICAgIGFjY2Vzc19sb2cgL3Zhci9sb2cvbmdpbngvYWNjZXNzLmxvZzsKICAgICAgICBlcnJvcl9sb2cgIC92YXIvbG9nL25naW54L2Vycm9yLmxvZzsKCiAgICAgICAgI3NzbF9jZXJ0aWZpY2F0ZSAgICAgL2V0Yy9sZXRzZW5jcnlwdC9saXZlLyR7cGlwX2Ruc30vZnVsbGNoYWluLnBlbTsKICAgICAgICAjc3NsX2NlcnRpZmljYXRlX2tleSAvZXRjL2xldHNlbmNyeXB0L2xpdmUvJHtwaXBfZG5zfS9wcml2a2V5LnBlbTsKCiAgICAgICAgIyBQZXJmZWN0IEZvcndhcmQgU2VjdXJpdHkKICAgICAgICBzc2xfcHJvdG9jb2xzIFRMU3YxLjI7CiAgICAgICAgc3NsX3ByZWZlcl9zZXJ2ZXJfY2lwaGVycyBvbjsKICAgICAgICBzc2xfY2lwaGVycyAiRUVDREgrRUNEU0ErQUVTR0NNIEVFQ0RIK0VDRFNBK1NIQTM4NCBFRUNESCtFQ0RTQStTSEEyNTYgRUVDREggIWFOVUxMICFlTlVMTCAhTE9XICEzREVTICFNRDUgIUVYUCAhUFNLICFTUlAgIURTUyAhUkM0ICFDQkMiOwogICAgICAgIHNzbF9zdGFwbGluZyBvbjsKICAgICAgICBzc2xfc3RhcGxpbmdfdmVyaWZ5IG9uOwogICAgICAgIHNzbF90cnVzdGVkX2NlcnRpZmljYXRlIC9ldGMvbGV0c2VuY3J5cHQvbGl2ZS8ke3BpcF9kbnN9L2Z1bGxjaGFpbi5wZW07CiAgICAgICAgc3NsX3Nlc3Npb25fY2FjaGUgICAgc2hhcmVkOlNTTDoxMG07CiAgICAgICAgc3NsX3Nlc3Npb25fdGltZW91dCAgMTBtOwoKICAgICAgICBsb2NhdGlvbiAvaGVhbHRoIHsKICAgICAgICAgICAgYWNjZXNzX2xvZyBvZmY7CiAgICAgICAgICAgIGFkZF9oZWFkZXIgQ29udGVudC1UeXBlIHRleHQvcGxhaW47CiAgICAgICAgICAgIHJldHVybiAyMDAgJ2NoZWVzZWJ1cmdlciFcbic7CiAgICAgICAgfQoKICAgICAgICBsb2NhdGlvbiAvIHsKICAgICAgICAgICAgI2FkZF9oZWFkZXIgU3RyaWN0LVRyYW5zcG9ydC1TZWN1cml0eSAibWF4LWFnZT0zMTUzNjAwMDsgaW5jbHVkZVN1YkRvbWFpbnMiIGFsd2F5czsKICAgICAgICAgICAgcHJveHlfcGFzcyBodHRwOi8vYmFja2VuZDsKICAgICAgICAgICAgcHJveHlfaHR0cF92ZXJzaW9uIDEuMTsKICAgICAgICAgICAgcHJveHlfc2V0X2hlYWRlciBVcGdyYWRlICRodHRwX3VwZ3JhZGU7CiAgICAgICAgICAgIHByb3h5X3NldF9oZWFkZXIgQ29ubmVjdGlvbiBrZWVwLWFsaXZlOwogICAgICAgICAgICBwcm94eV9zZXRfaGVhZGVyIEhvc3QgJGhvc3Q7CiAgICAgICAgICAgIHByb3h5X3NldF9oZWFkZXIgICBYLVJlYWwtSVAgICAgICAgICRyZW1vdGVfYWRkcjsKICAgICAgICAgICAgcHJveHlfc2V0X2hlYWRlciAgIFgtRm9yd2FyZGVkLUZvciAgJHByb3h5X2FkZF94X2ZvcndhcmRlZF9mb3I7CiAgICAgICAgICAgIHByb3h5X21heF90ZW1wX2ZpbGVfc2l6ZSAwOwogICAgICAgICAgICBwcm94eV9jb25uZWN0X3RpbWVvdXQgICAgICAyMDsKICAgICAgICAgICAgcHJveHlfc2VuZF90aW1lb3V0ICAgICAgICAgMjA7CiAgICAgICAgICAgIHByb3h5X3JlYWRfdGltZW91dCAgICAgICAgIDkwOwogICAgICAgICAgICBwcm94eV9idWZmZXJfc2l6ZSAgICAgICAgICA0azsKICAgICAgICAgICAgcHJveHlfYnVmZmVycyAgICAgICAgICAgICAgNCAzMms7CiAgICAgICAgICAgIHByb3h5X2J1c3lfYnVmZmVyc19zaXplICAgIDY0azsKICAgICAgICAgICAgcHJveHlfdGVtcF9maWxlX3dyaXRlX3NpemUgNjRrOwogICAgICAgIH0KICAgIH0KCn0=' | base64 -d  > /etc/nginx/nginx.conf \
      && echo $'#!/usr/bin/env bash\n\n/bin/su -s /bin/bash -c \'/opt/app_protect/bin/bd_agent &\' nginx\n/bin/su -s /bin/bash -c "/usr/share/ts/bin/bd-socket-plugin tmm_count 4 proc_cpuinfo_cpu_mhz 2000000 total_xml_memory 307200000 total_umu_max_size 3129344 sys_max_account_id 1024 no_static_config 2>&1 > /var/log/app_protect/bd-socket-plugin.log &" nginx' > ${WORKDIR}/entrypoint.sh \
      && chmod +x ${WORKDIR}/entrypoint.sh \
      && ${WORKDIR}/entrypoint.sh; \
    fi

# Forward request logs to Docker log collector:
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443
#USER 1001

STOPSIGNAL SIGTERM

#CMD ["nginx", "-g", "daemon off;"]
#CMD ["bash"]
CMD bash