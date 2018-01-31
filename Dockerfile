FROM php:7.1.9-alpine

ENV BUILD_DEPS \
                cmake \
                autoconf \
                g++ \
                gcc \
                make \
                pcre-dev \
                openssl-dev \
                libuv-dev \
                gmp-dev
ENV REDIS_VERSION 3.1.3
ENV IGBINARY_VERSION 2.0.4

RUN apk update && apk add --no-cache --virtual .build-deps $BUILD_DEPS \
    && apk add --no-cache git libuv gmp libstdc++ mariadb-client python py-pip

# Install PDO MySQL driver
RUN docker-php-ext-install pdo_mysql

# Install PDO Postgres driver

RUN docker-php-ext-install pdo pdo_pgsql

RUN set -ex \
  && apk --no-cache add \
    postgresql-dev

# Install XDebug
RUN pecl install xdebug \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable xdebug \
    && php -m | grep xdebug

# Install igbinary
RUN pecl install igbinary-$IGBINARY_VERSION \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable igbinary \
    && php -m | grep igbinary

# Install redis driver
RUN mkdir -p /tmp/pear \
    && cd /tmp/pear \
    && pecl bundle redis-$REDIS_VERSION \
    && cd redis \
    && phpize . \
    && ./configure --enable-redis-igbinary \
    && make \
    && make install \
    && cd ~ \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable redis \
    && php -m | grep redis

# Install DataStax C/C++ Driver
WORKDIR /lib
RUN git clone https://github.com/datastax/cpp-driver.git cpp-driver \
    && cd cpp-driver \
    && git checkout tags/2.7.0 \
    && mkdir build \
    && cd build \
    && cmake -DCASS_BUILD_STATIC=ON -DCASS_BUILD_SHARED=ON .. \
    && make -j4 \
    && make install

RUN ln -s /usr/local/lib64/libcassandra* /usr/local/lib/

# Install Cassandra PHP extension
RUN pecl install cassandra-1.3.2  \
    && docker-php-ext-enable cassandra \
    && rm -rf /tmp/pear \
    && php -m | grep cassandra

# Install composer
WORKDIR /tmp
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && php -r "unlink('composer-setup.php');"

# Install cqlsh
RUN pip install cqlsh

# Remove builddeps
RUN apk del .build-deps

ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php", "-a"]
