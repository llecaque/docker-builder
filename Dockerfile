# Copyright 2017-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file.
# This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or implied.
# See the License for the specific language governing permissions and limitations under the License.

FROM ubuntu:18.04

ENV RUBY_VERSION="2.6.3" \
 PYTHON_VERSION="3.7.3" \
 PHP_VERSION=7.3.6 \
 NODE_VERSION="10.16.0" \
 NODE_8_VERSION="8.16.0" \
 GOLANG_VERSION="1.12.5" \
 DOCKER_VERSION="18.09.6" \
 DOCKER_COMPOSE_VERSION="1.24.0"

#****************        Utilities     ********************************************* 
ENV DOCKER_BUCKET="download.docker.com" \    
    DOCKER_CHANNEL="stable" \
    DOCKER_SHA256="1f3f6774117765279fce64ee7f76abbb5f260264548cf80631d68fb2d795bb09" \
    DIND_COMMIT="3b5fac462d21ca164b3778647420016315289034" \    
    GITVERSION_VERSION="4.0.0" \
    DEBIAN_FRONTEND="noninteractive" \
    SRC_DIR="/usr/src"

# Install git, SSH, and other utilities
RUN set -ex \
    && echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/99use-gzip-compression \
    && apt-get update \
    && apt install -y apt-transport-https \
    && apt-get update \
    && apt-get install software-properties-common -y --no-install-recommends \
    && apt-add-repository -y ppa:git-core/ppa \
    && apt-get update \
    && apt-get install git=1:2.* -y --no-install-recommends \
    && git version \
    && apt-get install -y --no-install-recommends openssh-client \
    && mkdir ~/.ssh \
    && touch ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H github.com >> ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H bitbucket.org >> ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts \
    && apt-get install -y --no-install-recommends \
       wget python3 python3-dev python3-pip python3-setuptools fakeroot ca-certificates jq \
       netbase gnupg dirmngr bzr mercurial procps \
       tar gzip zip autoconf automake \
       bzip2 file g++ gcc imagemagick \
       libbz2-dev libc6-dev libcurl4-openssl-dev libdb-dev \
       libevent-dev libffi-dev libgeoip-dev libglib2.0-dev \
       libjpeg-dev libkrb5-dev liblzma-dev \
       libmagickcore-dev libmagickwand-dev libmysqlclient-dev \
       libncurses5-dev libpq-dev libreadline-dev \
       libsqlite3-dev libssl-dev libtool libwebp-dev \
       libxml2-dev libxslt1-dev libyaml-dev make \
       patch xz-utils zlib1g-dev unzip curl \
       e2fsprogs iptables xfsprogs \
       mono-devel less groff liberror-perl \
       asciidoc build-essential bzr cvs cvsps docbook-xml docbook-xsl dpkg-dev \
       libdbd-sqlite3-perl libdbi-perl libdpkg-perl libhttp-date-perl \
       libio-pty-perl libserf-1-1 libsvn-perl libsvn1 libtcl8.6 libtimedate-perl \
       libxml2-utils libyaml-perl python-bzrlib python-configobj \
       sgml-base sgml-data subversion tcl tcl8.6 xml-core xmlto xsltproc \
       tk gettext gettext-base libapr1 libaprutil1 xvfb expect parallel \
       locales rsync \
    && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF \
    && echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | tee /etc/apt/sources.list.d/mono-official-stable.list \    
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Download and set up GitVersion
RUN set -ex \
    && wget "https://github.com/GitTools/GitVersion/releases/download/v${GITVERSION_VERSION}/GitVersion-bin-net40-v${GITVERSION_VERSION}.zip" -O /tmp/GitVersion_${GITVERSION_VERSION}.zip \
    && mkdir -p /usr/local/GitVersion_${GITVERSION_VERSION} \
    && unzip /tmp/GitVersion_${GITVERSION_VERSION}.zip -d /usr/local/GitVersion_${GITVERSION_VERSION} \
    && rm /tmp/GitVersion_${GITVERSION_VERSION}.zip \
    && echo "mono /usr/local/GitVersion_${GITVERSION_VERSION}/GitVersion.exe \$@" >> /usr/local/bin/gitversion \
    && chmod +x /usr/local/bin/gitversion
# Install Docker
RUN set -ex \
    && curl -fSL "https://${DOCKER_BUCKET}/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
    && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
    && tar --extract --file docker.tgz --strip-components 1  --directory /usr/local/bin/ \
    && rm docker.tgz \
    && docker -v \
# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
    && addgroup dockremap \
    && useradd -g dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid \
    && wget "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
    && curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/dind /usr/local/bin/docker-compose \
# Ensure docker-compose works
    && docker-compose version

# https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_installation.html
RUN curl -sS -o /usr/local/bin/aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator \
    && curl -sS -o /usr/local/bin/kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/kubectl \
    && curl -sS -o /usr/local/bin/ecs-cli https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest \
    && chmod +x /usr/local/bin/kubectl /usr/local/bin/aws-iam-authenticator /usr/local/bin/ecs-cli

RUN set -ex \
    && pip3 install --upgrade setuptools wheel \
    && pip3 install awscli boto3  

VOLUME /var/lib/docker

# Configure SSH
COPY ssh_config /root/.ssh/config

COPY runtimes.yml /codebuild/image/config/runtimes.yml

COPY dockerd-entrypoint.sh /usr/local/bin/

#**************** RUBY *********************************************************

ENV RBENV_SRC_DIR="/usr/local/rbenv"

ENV PATH="/root/.rbenv/shims:$RBENV_SRC_DIR/bin:$RBENV_SRC_DIR/shims:$PATH" \
    RUBY_BUILD_SRC_DIR="$RBENV_SRC_DIR/plugins/ruby-build"

RUN set -ex \
    && git clone https://github.com/rbenv/rbenv.git $RBENV_SRC_DIR \
    && mkdir -p $RBENV_SRC_DIR/plugins \
    && git clone https://github.com/rbenv/ruby-build.git $RUBY_BUILD_SRC_DIR \
    && sh $RUBY_BUILD_SRC_DIR/install.sh \
    && rbenv install $RUBY_VERSION && rbenv global $RUBY_VERSION


RUN gem install berkshelf \
    && gem install aws-sdk 

#**************** END RUBY *****************************************************

#****************      PHP     ****************************************************
 ENV GPG_KEYS CBAF69F173A0FEA4B537F470D66C9593118BCCB6 F38252826ACD957EF380D39F2F7956BC5DA04B5D
 ENV PHP_DOWNLOAD_SHA="fefc8967daa30ebc375b2ab2857f97da94ca81921b722ddac86b29e15c54a164" \
     PHPPATH="/php" \
     PHP_INI_DIR="/usr/local/etc/php" \
     PHP_CFLAGS="-fstack-protector -fpic -fpie -O2" \
     PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"
 ENV PHP_SRC_DIR="$SRC_DIR/php" \
     PHP_CPPFLAGS="$PHP_CFLAGS" \
     PHP_URL="https://secure.php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" \
     PHP_ASC_URL="https://secure.php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror"
 RUN set -xe; \
     mkdir -p $SRC_DIR; \
     cd $SRC_DIR; \
     wget -O php.tar.xz "$PHP_URL"; \
     echo "$PHP_DOWNLOAD_SHA *php.tar.xz" | sha256sum -c -; \
     wget -O php.tar.xz.asc "$PHP_ASC_URL"; \
     export GNUPGHOME="$(mktemp -d)"; \
     for key in $GPG_KEYS; do \
         ( gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" \
           || gpg --keyserver pgp.mit.edu --recv-keys "$key" \
           || gpg --keyserver keyserver.pgp.com --recv-keys "$key" ); \
     done; \
     gpg --batch --verify php.tar.xz.asc php.tar.xz; \
     rm -rf "$GNUPGHOME"; \
     set -eux; \
     savedAptMark="$(apt-mark showmanual)"; \
     apt-get update; \
     apt-get install -y --no-install-recommends libedit-dev dpkg-dev libargon2-0-dev; \
     rm -rf /var/lib/apt/lists/*; \
     apt-get clean; \ 
     export \
         CFLAGS="$PHP_CFLAGS" \
         CPPFLAGS="$PHP_CPPFLAGS" \
         LDFLAGS="$PHP_LDFLAGS" \
     ; \
     mkdir -p $PHP_SRC_DIR; \
     tar -Jxf $SRC_DIR/php.tar.xz -C $PHP_SRC_DIR --strip-components=1; \
     cd $PHP_SRC_DIR; \
     gnuArch="$(dpkg-architecture -qDEB_BUILD_GNU_TYPE)"; \
     debMultiarch="$(dpkg-architecture -qDEB_BUILD_MULTIARCH)"; \
     if [ ! -d /usr/include/curl ]; then \
         ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
     fi; \
     ./configure \
         --build="$gnuArch" \
         --with-config-file-path="$PHP_INI_DIR" \
         --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
         --disable-cgi \
     # --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
         --enable-ftp \
     # --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
         --enable-mbstring \
     # --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
         --enable-mysqlnd \
         --enable-sockets \
         --enable-pcntl \
     # https://wiki.php.net/rfc/argon2_password_hash (7.2+)
         --with-password-argon2 \
         --with-curl \
         --with-pdo-pgsql \
         --with-pdo-mysql \
         --with-libedit \
         --with-openssl \
         --with-zlib \
     $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
         --with-libdir="lib/$debMultiarch" \
     ${PHP_EXTRA_CONFIGURE_ARGS:-} \
     ; \
     make -j "$(nproc)"; \
     make install; \
     find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; \
     make clean; \
     cd /; \
     rm -rf $PHP_SRC_DIR; \
     rm $SRC_DIR/php.tar.xz; \
     apt-mark auto '.*' > /dev/null; \
     [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
     find /usr/local -type f -executable -exec ldd '{}' ';' \
         | awk '/=>/ { print $(NF-1) }' \
         | sort -u \
         | xargs -r dpkg-query --search \
         | cut -d: -f1 \
         | sort -u \
         | xargs -r apt-mark manual \
     ; \
     apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
     php --version; \
     pecl update-channels; \
     rm -rf /tmp/pear ~/.pearrc; \
     mkdir "$PHP_INI_DIR"; \
     mkdir "$PHP_INI_DIR/conf.d"; \
     touch "$PHP_INI_DIR/conf.d/memory.ini" \
     && echo "memory_limit = 1G;" >> "$PHP_INI_DIR/conf.d/memory.ini";
 
 ENV PATH="$PHPPATH/bin:/usr/local/php/bin:$PATH"
 
 # Install Composer globally
 RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer
#****************      END PHP     ****************************************************

#****************      NODEJS     ****************************************************

 ENV N_SRC_DIR="$SRC_DIR/n"

 RUN git clone https://github.com/tj/n $N_SRC_DIR \
     && cd $N_SRC_DIR && make install \
     && n $NODE_8_VERSION && npm install --save-dev -g grunt && npm install --save-dev -g grunt-cli && npm install --save-dev -g webpack \
     && n $NODE_VERSION && npm install --save-dev -g grunt && npm install --save-dev -g grunt-cli && npm install --save-dev -g webpack \
     && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
     && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
     && apt-get update && apt-get install -y --no-install-recommends yarn \
     && cd / && rm -rf $N_SRC_DIR; 

#****************      END NODEJS     ****************************************************



