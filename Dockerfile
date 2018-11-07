FROM php:7.2.11-alpine3.8

LABEL repository.hub="alexmasterov/alpine-libv8:6.8" \
      repository.url="https://github.com/AlexMasterov/dockerfiles" \
      maintainer="Alex Masterov <alex.masterow@gmail.com>"

ARG V8_VERSION=6.8.104
ARG V8_DIR=/usr/local/v8

ARG BUILD_COMMIT=fb6dc3aba5f080908acb63b6dcd544c25051d793
ARG BUILDTOOLS_COMMIT=b7d53a93026d04002ca0705b5bf002de79c72165
ARG ICU_COMMIT=e4194dc7bbb3305d84cbb1b294274ca70d230721
ARG GTEST_COMMIT=a6f06bf2fd3b832822cd4e9e554b7d47f32ec084
ARG TRACE_EVENT_COMMIT=211b3ed9d0481b4caddbee1322321b86a483ca1f
ARG GYP_COMMIT=d61a9397e668fa9843c4aa7da9e79460fe590bfb
ARG CLANG_COMMIT=ec200e7a8308f301ade483408bcc79ca17ceb11e
ARG JINJA2_COMMIT=45571de473282bd1d8b63a8dfcb1fd268d0635d2
ARG MARKUPSAFE_COMMIT=8f45f5cfa0009d2a70589bcda0349b8cb2b72783

ARG GN_SOURCE=https://www.dropbox.com/s/3ublwqh4h9dit9t/alpine-gn-80e00be.tar.gz
ARG V8_SOURCE=https://chromium.googlesource.com/v8/v8/+archive/${V8_VERSION}.tar.gz

ENV V8_VERSION=${V8_VERSION} \
    V8_DIR=${V8_DIR}

# libbstdc++ for v8js    
RUN apk add --no-cache libstdc++

RUN set -x \
  && apk add --update --virtual .v8-build-dependencies \
    curl \
    g++ \
    gcc \
    glib-dev \
    icu-dev \
    linux-headers \
    make \
    ninja \
    python \
    tar \
    xz \
  && mkdir -p /tmp/v8 \
  && curl -fSL --connect-timeout 30 ${V8_SOURCE} | tar xmz -C /tmp/v8 \
  && DEPS=" \
    chromium/buildtools.git@${BUILDTOOLS_COMMIT}:buildtools; \
    chromium/src/build.git@${BUILD_COMMIT}:build; \
    chromium/src/base/trace_event/common.git@${TRACE_EVENT_COMMIT}:base/trace_event/common; \
    chromium/src/tools/clang.git@${CLANG_COMMIT}:tools/clang; \
    chromium/src/third_party/jinja2.git@${JINJA2_COMMIT}:third_party/jinja2; \
    chromium/src/third_party/markupsafe.git@${MARKUPSAFE_COMMIT}:third_party/markupsafe; \
    chromium/deps/icu.git@${ICU_COMMIT}:third_party/icu; \
    external/gyp.git@${GYP_COMMIT}:tools/gyp; \
    external/github.com/google/googletest.git@${GTEST_COMMIT}:third_party/googletest/src \
  " \
  && while [ "${DEPS}" ]; do \
    dep="${DEPS%%;*}" \
    link="${dep%%:*}" \
    url="${link%%@*}" url="${url#"${url%%[![:space:]]*}"}" \
    hash="${link#*@}" \
    dir="${dep#*:}"; \
    [ -n "${dep}" ] \
      && dep_url="https://chromium.googlesource.com/${url}/+archive/${hash}.tar.gz" \
      && dep_dir="/tmp/v8/${dir}" \
      && mkdir -p ${dep_dir} \
      && curl -fSL --connect-timeout 30 ${dep_url} | tar xmz -C ${dep_dir} \
      & [ "${DEPS}" = "${dep}" ] && DEPS='' || DEPS="${DEPS#*;}"; \
    done; \
    wait \
  && /tmp/v8/build/linux/sysroot_scripts/install-sysroot.py --arch=amd64 \
  && apk add --virtual .gn-runtime-dependencies \
    libevent \
    libexecinfo \
    libstdc++ \
  && curl -fSL --connect-timeout 30 ${GN_SOURCE} | tar xmz -C /tmp/v8/buildtools/linux64/ \
  && cd /tmp/v8 \
  && ./tools/dev/v8gen.py \
    x64.release \
    -- \
      binutils_path=\"/usr/bin\" \
      target_os=\"linux\" \
      target_cpu=\"x64\" \
      v8_target_cpu=\"x64\" \
      v8_use_external_startup_data=false \
      v8_enable_future=true \
      is_official_build=true \
      is_component_build=true \
      is_cfi=false \
      is_clang=false \
      use_custom_libcxx=false \
      use_sysroot=false \
      use_gold=false \
      use_allocator_shim=false \
      treat_warnings_as_errors=false \
      symbol_level=0 \
  && ninja d8 -C out.gn/x64.release/ -j $(getconf _NPROCESSORS_ONLN) \
  && mkdir -p ${V8_DIR}/include ${V8_DIR}/lib \
  && cp -R /tmp/v8/include/* ${V8_DIR}/include/ \
  && (cd /tmp/v8/out.gn/x64.release; \
      cp lib*.so icudtl.dat ${V8_DIR}/lib/) \
  && apk del .v8-build-dependencies .gn-runtime-dependencies \
  && rm -rf /var/cache/apk/* /var/tmp/* /tmp/*

ENV BUILD_DEPS \
                cmake \
                autoconf \
                g++ \
                gcc \
                make

RUN apk update  && apk add --no-cache --virtual .build-deps $BUILD_DEPS \
    && apk add --no-cache zlib-dev mariadb-client python git

# Install v8js driver
RUN mkdir -p /tmp/pear \
    && cd /tmp/pear \
    && pecl bundle v8js \
    && cd v8js \
    && phpize . \
    && ./configure --with-v8js=/opt/v8 LDFLAGS="-lstdc++" \
    && make \
    && make install \
    && cd ~ \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable v8js \
    && php -m | grep v8js

# Install zip
RUN docker-php-ext-install zip \
    && php -m | grep zip

# Install sockets
RUN docker-php-ext-install sockets \
    && php -m | grep sockets

# Install bcmath
RUN docker-php-ext-install bcmath \
    && php -m | grep bcmath  
    
# Install PDO MySQL driver
RUN docker-php-ext-install pdo_mysql \
    && php -m | grep pdo_mysql

# Install PostgreSQL libs
RUN apk add --no-cache postgresql-dev postgresql-client

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
