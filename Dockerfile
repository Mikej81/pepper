#FROM registry.access.redhat.com/ubi8/ubi:8.1
FROM centos:7.4.1708 as base

ARG PLATFORM

ARG nginxVer=1.16.1
ARG home=/usr/src

WORKDIR /usr/src

COPY dockerfile nginx-repo.crt nginx-repo.key ${WORKDIR}/

RUN if [[ ${PLATFORM} = "oss" ]] ; then \
      yum upgrade -y \
      && yum install epel-release -y \
      && yum groupinstall 'Development Tools' -y \
      && yum group mark install "Development Tools" \
      && yum group update "Development Tools" -y \
      && yum upgrade -y \
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
      && mv /usr/src/ModSecurity/unicode.mapping /etc/nginx/modsec/unicode.mapping \
      && yum --disableplugin=subscription-manager clean all -y \
      && rm -rf /var/cache/yum \
      && rm -rf /var/tmp/yum-* \
      && yum remove `package-cleanup --quiet --leaves` -y \
      && package-cleanup --oldkernels --count=1; \
    elif [[ ${PLATFORM} = "plus"  ]] ; then \
      mkdir /etc/ssl/nginx \
      && mv ${WORKDIR}/nginx-repo.* /etc/ssl/nginx/ \
      && yum upgrade -y \
      && yum -y install wget ca-certificates epel-release -y \
      && wget -P /etc/yum.repos.d https://cs.nginx.com/static/files/nginx-plus-7.repo \
      && yum -y install app-protect \
      && yum install nginx-plus-module-xslt nginx-plus-module-image-filter nginx-plus-module-perl nginx-plus-module-njs -y \
      && yum clean all \
      && rm -rf /var/cache/yum; \
    fi

FROM base as proxy 

ARG PLATFORM
ENV UPSTREAM_SERVER=example.com
ENV PLATFORM=${PLATFORM}

WORKDIR /usr/src
ARG home=/usr/src

RUN if [[ ${PLATFORM} = "oss" ]] ; then \
  cd ${home} \
  && git clone https://github.com/coreruleset/coreruleset.git \
  && mv coreruleset/rules/ /etc/nginx/modsec/ \
  && mv coreruleset/crs-setup.conf.example /etc/nginx/modsec/crs-setup.conf \
  && mv /etc/nginx/modsec/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example /etc/nginx/modsec/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf \
  && echo -e 'IyBOR0lOWCBTZWN1cmVkIFByb3h5IGluIGEgQm94CiMgTWljaGFlbCBDb2xlbWFuIEAgRjUKCnVzZXIgbmdpbng7Cndvcmtlcl9wcm9jZXNzZXMgYXV0bzsKCmVycm9yX2xvZyAgIC92YXIvbG9nL25naW54L2Vycm9yLmxvZyBub3RpY2U7CnBpZCAgICAgICAgIC9ydW4vbmdpbngucGlkOwoKbG9hZF9tb2R1bGUgbW9kdWxlcy9uZ3hfaHR0cF9tb2RzZWN1cml0eV9tb2R1bGUuc287CiNpbmNsdWRlIC91c3Ivc2hhcmUvbmdpbngvbW9kdWxlcy8qLmNvbmY7CgpldmVudHMgewogICAgd29ya2VyX2Nvbm5lY3Rpb25zICAxMDI0Owp9CgpodHRwIHsKICAgIGluY2x1ZGUgICAgICAgICAgICAgL2V0Yy9uZ2lueC9taW1lLnR5cGVzOwogICAgZGVmYXVsdF90eXBlICAgICAgICBhcHBsaWNhdGlvbi9vY3RldC1zdHJlYW07CgogICAgc2VydmVyX25hbWVzX2hhc2hfYnVja2V0X3NpemUgIDEyODsKCiAgICBsb2dfZm9ybWF0ICBtYWluICAnJHJlbW90ZV9hZGRyIC0gJHJlbW90ZV91c2VyIFskdGltZV9sb2NhbF0gIiRyZXF1ZXN0IiAnCiAgICAgICAgICAgICAgICAgICAgICAnJHN0YXR1cyAkYm9keV9ieXRlc19zZW50ICIkaHR0cF9yZWZlcmVyIiAnCiAgICAgICAgICAgICAgICAgICAgICAnIiRodHRwX3VzZXJfYWdlbnQiICIkaHR0cF94X2ZvcndhcmRlZF9mb3IiJzsKCiAgICBhY2Nlc3NfbG9nICAvdmFyL2xvZy9uZ2lueC9hY2Nlc3MubG9nICBtYWluOwoKICAgIHRjcF9ub2RlbGF5ICAgICAgICAgb247CiAgICBrZWVwYWxpdmVfdGltZW91dCAgIDY1OwogICAgdHlwZXNfaGFzaF9tYXhfc2l6ZSAyMDQ4OwoKICAgIGluY2x1ZGUgL2V0Yy9uZ2lueC9jb25mLmQvKi5jb25mOwoKICAgIHVwc3RyZWFtIGJhY2tlbmQgewogICAgICAgIHNlcnZlciAxNzIuMjE3LjYuMjI4OwogICAgfQoKICAgIHNlcnZlciB7CiAgICAgICAgbGlzdGVuIDgwOwogICAgICAgIGxpc3RlbiBbOjpdOjgwOwoKICAgICAgICBzZXJ2ZXJfbmFtZSAgXzsKCiAgICAgICAgbW9kc2VjdXJpdHkgb247CiAgICAgICAgbW9kc2VjdXJpdHlfcnVsZXNfZmlsZSAvZXRjL25naW54L21vZHNlY19pbmNsdWRlcy5jb25mOwoKICAgICAgICBhY2Nlc3NfbG9nIC92YXIvbG9nL25naW54L2FjY2Vzcy5sb2c7CiAgICAgICAgZXJyb3JfbG9nICAvdmFyL2xvZy9uZ2lueC9lcnJvci5sb2c7CgogICAgICAgICNzc2xfY2VydGlmaWNhdGUgICAgIC9ldGMvbGV0c2VuY3J5cHQvbGl2ZS8ke3BpcF9kbnN9L2Z1bGxjaGFpbi5wZW07CiAgICAgICAgI3NzbF9jZXJ0aWZpY2F0ZV9rZXkgL2V0Yy9sZXRzZW5jcnlwdC9saXZlLyR7cGlwX2Ruc30vcHJpdmtleS5wZW07CgogICAgICAgICMgUGVyZmVjdCBGb3J3YXJkIFNlY3VyaXR5CiAgICAgICAgc3NsX3Byb3RvY29scyBUTFN2MS4yOwogICAgICAgIHNzbF9wcmVmZXJfc2VydmVyX2NpcGhlcnMgb247CiAgICAgICAgc3NsX2NpcGhlcnMgIkVFQ0RIK0VDRFNBK0FFU0dDTSBFRUNESCtFQ0RTQStTSEEzODQgRUVDREgrRUNEU0ErU0hBMjU2IEVFQ0RIICFhTlVMTCAhZU5VTEwgIUxPVyAhM0RFUyAhTUQ1ICFFWFAgIVBTSyAhU1JQICFEU1MgIVJDNCAhQ0JDIjsKICAgICAgICBzc2xfc3RhcGxpbmcgb247CiAgICAgICAgc3NsX3N0YXBsaW5nX3ZlcmlmeSBvbjsKICAgICAgICBzc2xfdHJ1c3RlZF9jZXJ0aWZpY2F0ZSAvZXRjL2xldHNlbmNyeXB0L2xpdmUvJHtwaXBfZG5zfS9mdWxsY2hhaW4ucGVtOwogICAgICAgIHNzbF9zZXNzaW9uX2NhY2hlICAgIHNoYXJlZDpTU0w6MTBtOwogICAgICAgIHNzbF9zZXNzaW9uX3RpbWVvdXQgIDEwbTsKCiAgICAgICAgbG9jYXRpb24gL2hlYWx0aCB7CiAgICAgICAgICAgIGFjY2Vzc19sb2cgb2ZmOwogICAgICAgICAgICBhZGRfaGVhZGVyIENvbnRlbnQtVHlwZSB0ZXh0L3BsYWluOwogICAgICAgICAgICByZXR1cm4gMjAwICdjaGVlc2VidXJnZXIhXG4nOwogICAgICAgIH0KCiAgICAgICAgaW5jbHVkZSAvZXRjL25naW54L2RlZmF1bHQuZC8qLmNvbmY7CgogICAgICAgIGxvY2F0aW9uIC8gewogICAgICAgICAgICAjYWRkX2hlYWRlciBTdHJpY3QtVHJhbnNwb3J0LVNlY3VyaXR5ICJtYXgtYWdlPTMxNTM2MDAwOyBpbmNsdWRlU3ViRG9tYWlucyIgYWx3YXlzOwogICAgICAgICAgICBwcm94eV9wYXNzIGh0dHA6Ly9iYWNrZW5kOwogICAgICAgICAgICBwcm94eV9odHRwX3ZlcnNpb24gMS4xOwogICAgICAgICAgICBwcm94eV9zZXRfaGVhZGVyIFVwZ3JhZGUgJGh0dHBfdXBncmFkZTsKICAgICAgICAgICAgcHJveHlfc2V0X2hlYWRlciBDb25uZWN0aW9uIGtlZXAtYWxpdmU7CiAgICAgICAgICAgIHByb3h5X3NldF9oZWFkZXIgSG9zdCAkaG9zdDsKICAgICAgICAgICAgcHJveHlfc2V0X2hlYWRlciAgIFgtUmVhbC1JUCAgICAgICAgJHJlbW90ZV9hZGRyOwogICAgICAgICAgICBwcm94eV9zZXRfaGVhZGVyICAgWC1Gb3J3YXJkZWQtRm9yICAkcHJveHlfYWRkX3hfZm9yd2FyZGVkX2ZvcjsKICAgICAgICAgICAgcHJveHlfbWF4X3RlbXBfZmlsZV9zaXplIDA7CiAgICAgICAgICAgIHByb3h5X2Nvbm5lY3RfdGltZW91dCAgICAgIDIwOwogICAgICAgICAgICBwcm94eV9zZW5kX3RpbWVvdXQgICAgICAgICAyMDsKICAgICAgICAgICAgcHJveHlfcmVhZF90aW1lb3V0ICAgICAgICAgOTA7CiAgICAgICAgICAgIHByb3h5X2J1ZmZlcl9zaXplICAgICAgICAgIDRrOwogICAgICAgICAgICBwcm94eV9idWZmZXJzICAgICAgICAgICAgICA0IDMyazsKICAgICAgICAgICAgcHJveHlfYnVzeV9idWZmZXJzX3NpemUgICAgNjRrOwogICAgICAgICAgICBwcm94eV90ZW1wX2ZpbGVfd3JpdGVfc2l6ZSA2NGs7CiAgICAgICAgfQogICAgfQp9' | base64 -d  > /etc/nginx/nginx.conf \
  && echo -e 'IyBGcm9tIGh0dHBzOi8vZ2l0aHViLmNvbS9TcGlkZXJMYWJzL01vZFNlY3VyaXR5L2Jsb2IvbWFzdGVyLwojIG1vZHNlY3VyaXR5LmNvbmYtcmVjb21tZW5kZWQKIwojIEVkaXQgdG8gc2V0IFNlY1J1bGVFbmdpbmUgT24KSW5jbHVkZSAiL2V0Yy9uZ2lueC9tb2RzZWMvbW9kc2VjdXJpdHkuY29uZiIKCiNJbmNsdWRlIC9ldGMvbmdpbngvbW9kc2VjL2Nycy1zZXR1cC5jb25mCiNJbmNsdWRlIC9ldGMvbmdpbngvbW9kc2VjL3J1bGVzLyouY29uZgojSW5jbHVkZSAvZXRjL25naW54L21vZHNlYy9SRVNQT05TRS05OTktRVhDTFVTSU9OLVJVTEVTLUFGVEVSLUNSUy5jb25mCgojIEJhc2ljIHRlc3QgcnVsZQpTZWNSdWxlIEFSR1M6dGVzdHBhcmFtICJAY29udGFpbnMgdGVzdCIgImlkOjEyMzQsZGVueSxzdGF0dXM6NDAzIg==' | base64 -d > /etc/nginx/modsec_includes.conf; \
elif [[ ${PLATFORM} = "plus"  ]] ; then \
  echo -e 'IyBOR0lOWCBTZWN1cmVkIFByb3h5IGluIGEgQm94CiMgTWljaGFlbCBDb2xlbWFuIEAgRjUKCnVzZXIgbmdpbng7Cgp3b3JrZXJfcHJvY2Vzc2VzIGF1dG87CmxvYWRfbW9kdWxlIG1vZHVsZXMvbmd4X2h0dHBfYXBwX3Byb3RlY3RfbW9kdWxlLnNvOwpsb2FkX21vZHVsZSBtb2R1bGVzL25neF9odHRwX2dlb2lwX21vZHVsZS5zbzsKbG9hZF9tb2R1bGUgbW9kdWxlcy9uZ3hfc3RyZWFtX2dlb2lwX21vZHVsZS5zbzsKCmVycm9yX2xvZyAvdmFyL2xvZy9uZ2lueC9lcnJvci5sb2cgZGVidWc7CgpldmVudHMgewogICAgd29ya2VyX2Nvbm5lY3Rpb25zIDEwMjQwOwp9CgpodHRwIHsKICAgIGluY2x1ZGUgICAgICAgL2V0Yy9uZ2lueC9taW1lLnR5cGVzOwogICAgZGVmYXVsdF90eXBlICBhcHBsaWNhdGlvbi9vY3RldC1zdHJlYW07CgogICAgc2VydmVyX25hbWVzX2hhc2hfYnVja2V0X3NpemUgIDEyODsKCiAgICBsb2dfZm9ybWF0ICBtYWluICAnJHJlbW90ZV9hZGRyIC0gJHJlbW90ZV91c2VyIFskdGltZV9sb2NhbF0gIiRyZXF1ZXN0IiAnCiAgICAgICAgICAgICAgICAgICAgICAnJHN0YXR1cyAkYm9keV9ieXRlc19zZW50ICIkaHR0cF9yZWZlcmVyIiAnCiAgICAgICAgICAgICAgICAgICAgICAnIiRodHRwX3VzZXJfYWdlbnQiICIkaHR0cF94X2ZvcndhcmRlZF9mb3IiJzsKCiAgICBhY2Nlc3NfbG9nICAvdmFyL2xvZy9uZ2lueC9hY2Nlc3MubG9nICBtYWluOwoKICAgIHRjcF9ub2RlbGF5ICAgICAgICAgb247CiAgICBrZWVwYWxpdmVfdGltZW91dCAgIDY1OwogICAgdHlwZXNfaGFzaF9tYXhfc2l6ZSAyMDQ4OwoKICAgIHVwc3RyZWFtIGJhY2tlbmQgewogICAgICAgIHNlcnZlciAxNzIuMjE3LjYuMjI4OwogICAgfQoKICAgIHNlcnZlciB7CiAgICAgICAgbGlzdGVuICAgICAgIDgwIDsKICAgICAgICBwcm94eV9odHRwX3ZlcnNpb24gMS4xOwoKICAgICAgICBhcHBfcHJvdGVjdF9lbmFibGUgb247CiAgICAgICAgYXBwX3Byb3RlY3Rfc2VjdXJpdHlfbG9nX2VuYWJsZSBvbjsKICAgICAgICBhcHBfcHJvdGVjdF9zZWN1cml0eV9sb2cgIi9ldGMvbmdpbngvY3VzdG9tX2xvZ19mb3JtYXQuanNvbiIgc3lzbG9nOnNlcnZlcj0xMjcuMC4wLjE6NTE1OwoKICAgICAgICBzZXJ2ZXJfbmFtZSAgXzsKCiAgICAgICAgI3NzbF9jZXJ0aWZpY2F0ZSAgICAgL2V0Yy9sZXRzZW5jcnlwdC9saXZlLyR7cGlwX2Ruc30vZnVsbGNoYWluLnBlbTsKICAgICAgICAjc3NsX2NlcnRpZmljYXRlX2tleSAvZXRjL2xldHNlbmNyeXB0L2xpdmUvJHtwaXBfZG5zfS9wcml2a2V5LnBlbTsKCiAgICAgICAgIyBQZXJmZWN0IEZvcndhcmQgU2VjdXJpdHkKICAgICAgICBzc2xfcHJvdG9jb2xzIFRMU3YxLjI7CiAgICAgICAgc3NsX3ByZWZlcl9zZXJ2ZXJfY2lwaGVycyBvbjsKICAgICAgICBzc2xfY2lwaGVycyAiRUVDREgrRUNEU0ErQUVTR0NNIEVFQ0RIK0VDRFNBK1NIQTM4NCBFRUNESCtFQ0RTQStTSEEyNTYgRUVDREggIWFOVUxMICFlTlVMTCAhTE9XICEzREVTICFNRDUgIUVYUCAhUFNLICFTUlAgIURTUyAhUkM0ICFDQkMiOwogICAgICAgIHNzbF9zdGFwbGluZyBvbjsKICAgICAgICBzc2xfc3RhcGxpbmdfdmVyaWZ5IG9uOwogICAgICAgIHNzbF9zZXNzaW9uX2NhY2hlICAgIHNoYXJlZDpTU0w6MTBtOwogICAgICAgIHNzbF9zZXNzaW9uX3RpbWVvdXQgIDEwbTsKCiAgICAgICAgbG9jYXRpb24gL2hlYWx0aCB7CiAgICAgICAgICAgIGFjY2Vzc19sb2cgb2ZmOwogICAgICAgICAgICBhZGRfaGVhZGVyIENvbnRlbnQtVHlwZSB0ZXh0L3BsYWluOwogICAgICAgICAgICByZXR1cm4gMjAwICdjaGVlc2VidXJnZXIhXG4nOwogICAgICAgIH0KCiAgICAgICAgbG9jYXRpb24gLyB7CiAgICAgICAgICAgICNhZGRfaGVhZGVyIFN0cmljdC1UcmFuc3BvcnQtU2VjdXJpdHkgIm1heC1hZ2U9MzE1MzYwMDA7IGluY2x1ZGVTdWJEb21haW5zIiBhbHdheXM7CiAgICAgICAgICAgIHByb3h5X3Bhc3MgaHR0cDovL2JhY2tlbmQ7CiAgICAgICAgICAgIHByb3h5X2h0dHBfdmVyc2lvbiAxLjE7CiAgICAgICAgICAgIHByb3h5X3NldF9oZWFkZXIgVXBncmFkZSAkaHR0cF91cGdyYWRlOwogICAgICAgICAgICBwcm94eV9zZXRfaGVhZGVyIENvbm5lY3Rpb24ga2VlcC1hbGl2ZTsKICAgICAgICAgICAgcHJveHlfc2V0X2hlYWRlciBIb3N0ICRob3N0OwogICAgICAgICAgICBwcm94eV9zZXRfaGVhZGVyICAgWC1SZWFsLUlQICAgICAgICAkcmVtb3RlX2FkZHI7CiAgICAgICAgICAgIHByb3h5X3NldF9oZWFkZXIgICBYLUZvcndhcmRlZC1Gb3IgICRwcm94eV9hZGRfeF9mb3J3YXJkZWRfZm9yOwogICAgICAgICAgICBwcm94eV9tYXhfdGVtcF9maWxlX3NpemUgMDsKICAgICAgICAgICAgcHJveHlfY29ubmVjdF90aW1lb3V0ICAgICAgMjA7CiAgICAgICAgICAgIHByb3h5X3NlbmRfdGltZW91dCAgICAgICAgIDIwOwogICAgICAgICAgICBwcm94eV9yZWFkX3RpbWVvdXQgICAgICAgICA5MDsKICAgICAgICAgICAgcHJveHlfYnVmZmVyX3NpemUgICAgICAgICAgNGs7CiAgICAgICAgICAgIHByb3h5X2J1ZmZlcnMgICAgICAgICAgICAgIDQgMzJrOwogICAgICAgICAgICBwcm94eV9idXN5X2J1ZmZlcnNfc2l6ZSAgICA2NGs7CiAgICAgICAgICAgIHByb3h5X3RlbXBfZmlsZV93cml0ZV9zaXplIDY0azsKICAgICAgICB9CiAgICB9Cgp9' | base64 -d  > /etc/nginx/nginx.conf \
  && echo -e 'ewogICAgImZpbHRlciI6IHsKICAgICAgICAicmVxdWVzdF90eXBlIjogImFsbCIKICAgIH0sCiAgICAiY29udGVudCI6IHsKICAgICAgICAiZm9ybWF0IjogInNwbHVuayIsCiAgICAgICAgIm1heF9yZXF1ZXN0X3NpemUiOiAiYW55IiwKICAgICAgICAibWF4X21lc3NhZ2Vfc2l6ZSI6ICIxMGsiCiAgICB9Cn0=' | base64 -d > /etc/nginx/custom_log_format.json \
  && wget -P /etc/yum.repos.d https://cs.nginx.com/static/files/app-protect-signatures-7.repo \
  && yum install app-protect-threat-campaigns -y \
  && yum install app-protect-attack-signatures -y \
  && rm -rf /etc/ssl/nginx; \
fi

# Create Entrypoint.sh
RUN echo -e 'IyEvdXNyL2Jpbi9lbnYgYmFzaAoKaWYgW1sgJFBMQVRGT1JNID0gInBsdXMiIF1dOyB0aGVuCiAgICB5dW0gaW5zdGFsbCBhcHAtcHJvdGVjdC1hdHRhY2stc2lnbmF0dXJlcyAteQogICAgeXVtIGluc3RhbGwgYXBwLXByb3RlY3QtdGhyZWF0LWNhbXBhaWducyAteQogICAgL2Jpbi9zdSAtcyAvYmluL2Jhc2ggLWMgJy9vcHQvYXBwX3Byb3RlY3QvYmluL2JkX2FnZW50ICYnIG5naW54CiAgICAvYmluL3N1IC1zIC9iaW4vYmFzaCAtYyAiL3Vzci9zaGFyZS90cy9iaW4vYmQtc29ja2V0LXBsdWdpbiB0bW1fY291bnQgNCBwcm9jX2NwdWluZm9fY3B1X21oeiAyMDAwMDAwIHRvdGFsX3htbF9tZW1vcnkgMzA3MjAwMDAwIHRvdGFsX3VtdV9tYXhfc2l6ZSAzMTI5MzQ0IHN5c19tYXhfYWNjb3VudF9pZCAxMDI0IG5vX3N0YXRpY19jb25maWcgMj4mMSA+IC92YXIvbG9nL2FwcF9wcm90ZWN0L2JkLXNvY2tldC1wbHVnaW4ubG9nICYiIG5naW54CiAgICAvdXNyL3NiaW4vbmdpbnggLWcgJ2RhZW1vbiBvZmY7JwplbHNlCiAgICAvdXNyL3NiaW4vbmdpbnggLWcgJ2RhZW1vbiBvZmY7JwpmaQ==' | base64 -d > ${home}/entrypoint.sh \
  && chmod +x ${home}/entrypoint.sh

# Forward request logs to Docker log collector:
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443
#USER 1001

STOPSIGNAL SIGTERM

CMD ["sh", "/usr/src/entrypoint.sh"] 
#CMD ["bash"]