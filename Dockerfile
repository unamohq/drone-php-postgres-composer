FROM php:7.2.6-cli-alpine3.7

ENV BUILD_DEPS \
                cmake \
                autoconf \
                g++ \
                gcc \
                make

RUN apk update  && apk add --no-cache --virtual .build-deps $BUILD_DEPS \
    && apk add --no-cache zlib-dev mariadb-client python git

# Install ast
RUN pecl install ast \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable ast \
    && php -m | grep ast

# Install zip
RUN docker-php-ext-install zip \
    && php -m | grep zip

# Install PDO MySQL driver
RUN docker-php-ext-install pdo_mysql \
    && php -m | grep pdo_mysql

# Install PostgreSQL libs
RUN apk add --no-cache postgresql-dev

# Install PDO PostgreSQL driver
RUN docker-php-ext-install pdo_pgsql \
    && php -m | grep pdo_mysql

# Install XDebug
RUN pecl install xdebug \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable xdebug \
    && php -m | grep xdebug

# Install igbinary
RUN pecl install igbinary \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable igbinary \
    && php -m | grep igbinary

# Install redis driver
RUN mkdir -p /tmp/pear \
    && cd /tmp/pear \
    && pecl bundle redis \
    && cd redis \
    && phpize . \
    && ./configure --enable-redis-igbinary \
    && make \
    && make install \
    && cd ~ \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable redis \
    && php -m | grep redis

# Install composer
WORKDIR /tmp
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && php -r "unlink('composer-setup.php');"

# Remove builddeps
RUN apk del .build-deps

ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php", "-a"]

