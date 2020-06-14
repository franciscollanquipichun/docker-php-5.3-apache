FROM debian:jessie
LABEL maintainer="https://github.com/cristianorsolin/docker-php-5.3-apache"

ENV PHP_VERSION 5.3.29
ENV PHP_INI_DIR /etc/php5/apache2

# persistent / runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      postgresql-client \
      librecode0 \
      libmysqlclient-dev \
      libsqlite3-0 \
      libxml2 \
      libpq-dev \
      libmemcached-dev \
      libpng12-dev \
      libfreetype6-dev \
      libssl-dev \
      libmcrypt-dev \
# phpize deps
      autoconf \
      file \
      g++ \
      gcc \
      libc-dev \
      make \
      pkg-config \
      re2c \
# apache2
      apache2-bin apache2-dev apache2.2-common \
    && apt-get clean \
    && rm -r /var/lib/apt/lists/*

# apache2
RUN rm -rf /var/www/html && mkdir -p /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html && chown -R www-data:www-data /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html

# Apache + PHP requires preforking Apache for best results
RUN a2dismod mpm_event && a2enmod mpm_prefork
RUN mv /etc/apache2/apache2.conf /etc/apache2/apache2.conf.dist
COPY apache2.conf /etc/apache2/apache2.conf
RUN mkdir -p $PHP_INI_DIR/conf.d

# php 5.3 needs older autoconf
# --enable-mysqlnd is included below because it's harder to compile after the fact the extensions are (since it's a plugin for several extensions, not an extension in itself)
RUN buildDeps=" \
                apache2-dev \
                autoconf2.13 \
                libcurl4-openssl-dev \
                libreadline6-dev \
                librecode-dev \
                libsqlite3-dev \
                libssl-dev \
                libxml2-dev \
                libpng-dev \
                xz-utils \
      " \
      && set -x \
      && apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
      && curl -SL "http://php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" -o php.tar.xz \
      && curl -SL "http://php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror" -o php.tar.xz.asc \
      #&& gpg --verify php.tar.xz.asc php.tar.xz \
      && mkdir -p /usr/src/php \
      && tar -xof php.tar.xz -C /usr/src/php --strip-components=1 \
      && rm php.tar.xz* \
      && cd /usr/src/php \
      && ./configure --disable-cgi \
            $(command -v apxs2 > /dev/null 2>&1 && echo '--with-apxs2=/usr/bin/apxs2' || true) \
            --with-config-file-path="$PHP_INI_DIR" \
            --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
            --enable-ftp \
            --enable-mbstring \
            --enable-mysqlnd \
            --with-mysql \
            --with-pgsql \
            --with-mysqli \
            --with-pdo-mysql \
            --with-pdo_pgsql \
            --with-curl \
            #--with-openssl=/usr/local/ssl \
            --enable-soap \
            --with-png \
            --with-gd \
            --with-readline \
            --with-recode \
            --with-zlib \
            --with-mcrypt \
      && make -j"$(nproc)" \
      && make install \
      && { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
      && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps \
      && make clean

RUN echo "default_charset = " > $PHP_INI_DIR/php.ini \
    && echo "date.timezone = America/Sao_Paulo" >> $PHP_INI_DIR/php.ini

COPY docker-php-* /usr/local/bin/
COPY apache2-foreground /usr/local/bin/

WORKDIR /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
