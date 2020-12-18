	# define build argument defaults.
# ------------------------------------------------------------------------------
ARG BUILD_IMAGE_NAME=php
ARG BUILD_IMAGE_TAG=7.2-apache
ARG BUILD_CONTAINER_PORT=8000


# specify the image name and tag to base the build image off.
# ------------------------------------------------------------------------------
FROM ${BUILD_IMAGE_NAME}:${BUILD_IMAGE_TAG}

# This is needed specifically for the odbc package
ENV ACCEPT_EULA=Y

# create the application home directory and make it the working directory.
# ------------------------------------------------------------------------------
RUN mkdir -p /home/tmo/src_code
WORKDIR /home/tmo/src_code

# Microsoft SQL Server Prerequisites
## There may be duplicate packages here dpeending on the copy paste job I did from here: https://laravel-news.com/install-microsoft-sql-drivers-php-7-docker
### From what I can tell I think maybe the apt-transport-https is probably duplicated it s a fairly common package
RUN apt-get update 
## NEED THIS
RUN apt-get install -y gpgv
RUN wget -q -O - https://packages.microsoft.com/keys/microsoft.asc | apt-key add - 
RUN curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN apt-get install -y --no-install-recommends locales apt-transport-https	
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen
RUN apt-get update
RUN apt-get -y --no-install-recommends install \
    unixodbc-dev \
    msodbcsql17

RUN apt-get update 
RUN apt-get install -y --no-install-recommends locales apt-transport-https

RUN docker-php-ext-install mbstring pdo pdo_mysql \
    && pecl install sqlsrv pdo_sqlsrv \
    && docker-php-ext-enable sqlsrv pdo_sqlsrv
# update 'apt-get' and install required packages.
# ------------------------------------------------------------------------------
RUN apt-get update
RUN apt-get install -y \
# added vim so we can edit files
	vim \
	git \
	zip \                            
	curl \
	sudo \
	unzip \
	libicu-dev \
	libbz2-dev \
	libpng-dev \
	libjpeg-dev \
	libldap2-dev \
	libmcrypt-dev \
	libreadline-dev \
	libfreetype6-dev \
	g++ 


# configure ldap php extension.
# ------------------------------------------------------------------------------
RUN docker-php-ext-install ldap && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ 


# configure PHP environment and install PHP extensions.
# ------------------------------------------------------------------------------
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
RUN docker-php-ext-install \
	bz2 \
	intl \
	iconv \
	bcmath \
	opcache \
	calendar \
	mbstring \
	pdo_mysql \
	zip


# create container-scoped user to prevent host permission inheritance.
# ------------------------------------------------------------------------------
ARG UID
RUN useradd -u $UID -m tmo && \
	usermod -aG www-data,root tmo
USER tmo
RUN mkdir -p /home/tmo/src_code

# copy source files to working directory.
# ------------------------------------------------------------------------------
COPY ./ /home/tmo/src_code

USER root

# simplest way to configure nginx.conf file
RUN cp ${NGINX_CONFIG_PATH} ${NGINX_SITE_DIRECTORY}

# install composer.
# ------------------------------------------------------------------------------
COPY --from=docker.io/library/composer:latest /usr/bin/composer /usr/bin/composer
RUN cp /usr/bin/composer /home/tmo/src_code/.composer

# install node.js.
# ------------------------------------------------------------------------------
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
	&& apt-get install -y nodejs

## Replace the default nginx index page with our Angular app
#RUN rm -rf /usr/share/nginx/html/*
#COPY {$} /usr/share/nginx/html

COPY {$NGINX_CONFIG_PATH} /etc/nginx/nginx.conf

ENTRYPOINT ["nginx", "-g", "daemon off;"]

# specify the port the application is listening on.
# ------------------------------------------------------------------------------
EXPOSE ${BUILD_CONTAINER_PORT}
