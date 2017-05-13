FROM ubuntu:16.04
MAINTAINER Rija Menage <dockerfiles@rija.cinecinetique.com>

EXPOSE 80
EXPOSE 443

CMD ["/usr/bin/supervisord"]

# Keep upstart from complaining (see https://ubuntuforums.org/showthread.php?t=1997229)
RUN dpkg-divert --local --rename --add /sbin/initctl && ln -sf /bin/true /sbin/initctl

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive


# Basic Dependencies
RUN apt-get update && apt-get install -y pwgen \
						python-setuptools \
						apt-utils \
						curl \
						git \
						jq \
						vim \
						cron \
						unzip


# mysql

RUN apt-get update && apt-get install -y mysql-client

# php 7 installation

RUN apt-get clean && apt-get -y update && apt-get install -y locales

RUN locale-gen en_US.UTF-8
ENV  LANG en_US.UTF-8
ENV  LC_ALL en_US.UTF-8
RUN apt-get install -y software-properties-common
RUN LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php
RUN apt-get update && apt-get install -y php7.0 \
						php7.0-fpm \
						php7.0-mysql


# installing Fail2ban
RUN apt-get update && apt-get install -y fail2ban


# Wordpress Requirements
RUN apt-get update && apt-get install -y php7.0-curl \
						php7.0-gd \
						php7.0-intl \
						php-pear \
						php7.0-imagick \
						php7.0-imap \
						php7.0-mcrypt \
						php7.0-memcache \
						php7.0-ps \
						php7.0-pspell \
						php7.0-recode \
						php7.0-sqlite \
						php7.0-tidy \
						php7.0-xmlrpc \
						php7.0-xml \
						php7.0-xsl \
						php7.0-opcache \
						php7.0-mbstring \
						php-gettext



# install unattended upgrades and supervisor
RUN apt-get update && apt-get install -y supervisor \
						unattended-upgrades

# unattended upgrade configuration
COPY 02periodic /etc/apt/apt.conf.d/02periodic


# install nginx with ngx_http_upstream_fair_module and ngx_cache_purge


RUN apt-get update && apt-get install -y build-essential zlib1g-dev libpcre3 libpcre3-dev unzip libssl-dev libgeoip-dev
RUN apt-get update && apt-get install -y nginx-light
RUN cd /tmp \
		&& curl -O https://nginx.org/download/nginx-1.13.0.tar.gz \
		&& tar xzvf nginx-1.13.0.tar.gz \
		&& curl -O http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz \
		&& test `openssl sha1 ngx_cache_purge-2.3.tar.gz | cut -d"=" -f2` = 69ed46a23435e8dfd5579422c0c3996cf9a44291 \
		&& tar xzvf ngx_cache_purge-2.3.tar.gz

RUN cd /tmp/nginx-1.13.0 \
		&& ./configure --prefix=/usr/share/nginx \
		--with-cc-opt='-g -O2 -fPIE -fstack-protector-strong -Wformat \
		-Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2' \
		--with-ld-opt='-Wl,-Bsymbolic-functions -fPIE -pie -Wl,-z,relro -Wl,-z,now' \
		--conf-path=/etc/nginx/nginx.conf \
		--http-log-path=/var/log/nginx/access.log \
		--error-log-path=/var/log/nginx/error.log \
		--lock-path=/var/lock/nginx.lock \
		--pid-path=/run/nginx.pid \
		--http-client-body-temp-path=/var/lib/nginx/body \
		--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
		--http-proxy-temp-path=/var/lib/nginx/proxy  \
		--with-debug \
		--with-pcre-jit \
		--with-ipv6 \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--with-http_realip_module \
		--with-http_auth_request_module \
		--with-http_addition_module \
		--with-http_geoip_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_v2_module \
		--with-http_sub_module \
		--with-stream \
		--with-stream_ssl_module \
		--with-threads  \
		--add-module=/tmp/ngx_cache_purge-2.3 \
		&& make && make install
RUN ln -fs /usr/share/nginx/sbin/nginx /usr/sbin/nginx


# Install LE's ACME client for domain validation and certificate generation and renewal
RUN apt-get install -y letsencrypt
RUN mkdir -p /tmp/le


# nginx config
RUN adduser --system --no-create-home --shell /bin/false --group --disabled-login www-front
COPY  nginx.conf /etc/nginx/nginx.conf
COPY  restrictions.conf /etc/nginx/restrictions.conf
COPY  ssl.conf /etc/nginx/ssl.conf
COPY  security_headers.conf /etc/nginx/security_headers.conf
COPY  le.ini /etc/nginx/le.ini
COPY  acme.challenge.le.conf /etc/nginx/acme.challenge.le.conf
COPY  nginx-site.conf /etc/nginx/sites-available/default
RUN openssl dhparam -out /etc/nginx/dhparam.pem 2048


# php-fpm config: Opcode cache config
RUN sed -i -e"s/^;opcache.enable=0/opcache.enable=1/" /etc/php/7.0/fpm/php.ini
RUN sed -i -e"s/^;opcache.max_accelerated_files=2000/opcache.max_accelerated_files=4000/" /etc/php/7.0/fpm/php.ini


# php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/7.0/fpm/php.ini
RUN sed -i -e "s/expose_php = On/expose_php = Off/g" /etc/php/7.0/fpm/php.ini
RUN sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php/7.0/fpm/php.ini
RUN sed -i -e "s/;session.cookie_secure\s*=\s*/session.cookie_secure = True/g" /etc/php/7.0/fpm/php.ini
RUN sed -i -e "s/session.cookie_httponly\s*=\s*/session.cookie_httponly = True/g" /etc/php/7.0/fpm/php.ini
RUN sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php/7.0/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.0/fpm/php-fpm.conf
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.0/fpm/pool.d/www.conf
RUN sed -i -e "s/listen\s*=\s*\/run\/php\/php7.0-fpm.sock/listen = 127.0.0.1:9000/g" /etc/php/7.0/fpm/pool.d/www.conf
RUN sed -i -e "s/;listen.allowed_clients\s*=\s*127.0.0.1/listen.allowed_clients = 127.0.0.1/g" /etc/php/7.0/fpm/pool.d/www.conf
RUN sed -i -e "s/;access.log\s*=\s*log\/\$pool.access.log/access.log = \/var\/log\/\$pool.access.log/g" /etc/php/7.0/fpm/pool.d/www.conf

# create the pid and sock file for php-fpm
RUN service php7.0-fpm start
RUN touch /var/log/php7.0-fpm.log && chown www-data:www-data /var/log/php7.0-fpm.log

# Supervisor Config
RUN /usr/bin/easy_install supervisor-stdout
RUN mkdir -p /var/log/supervisor
COPY  ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# Select Vanilla Wordpress or Git install

ARG WP_VANILLA
ARG GIT_SSH_URL
ENV WP_VANILLA ${WP_VANILLA:-1}
ENV GIT_SSH_URL ${GIT_SSH_URL:-''}


# Download Wordpress

ARG WP_VERSION
ENV WP_VERSION ${WP_VERSION:-4.5.3}

COPY download_wordpress /download_wordpress
RUN chmod 755 /download_wordpress
RUN /download_wordpress

# Install Wordpress

COPY install_wordpress /install_wordpress
RUN chmod 755 /install_wordpress
RUN /install_wordpress

# Bootstrap logs
RUN mkdir -p /var/log/nginx \
		&& touch /var/log/nginx/error.log \
		&& touch /var/log/nginx/access.log

RUN chown -R www-front:www-front /var/log/nginx \
		&& chown www-front:www-front /var/log/nginx/error.log \
		&& chown www-front:www-front /var/log/nginx/access.log

# cronjob for certificate auto renewal
COPY crontab /etc/certs.cron
RUN touch /var/log/certs.log
RUN crontab /etc/certs.cron


# Wordpress Initialization and Startup Script
COPY  ./bootstrap.sh /bootstrap.sh
RUN chmod 755 /bootstrap.sh
