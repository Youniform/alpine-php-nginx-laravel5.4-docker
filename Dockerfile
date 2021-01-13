FROM alpine:3.12
LABEL Maintainer="Tim de Pater <code@trafex.nl>" \
      Description="Lightweight container with Nginx 1.18 & PHP-FPM 7.3 based on Alpine Linux."

# Install packages and remove default server definition
RUN apk --no-cache add php7 php7-fpm php7-opcache php7-mysqli php7-json php7-openssl php7-curl \
    php7-zlib php7-xml php7-phar php7-intl php7-dom php7-xmlreader php7-ctype php7-session \
    php7-mbstring php7-gd nginx supervisor curl openssl wget mariadb mariadb-client && \
    rm /etc/nginx/conf.d/default.conf

# Configure nginx
COPY ./docker_config_files/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY ./docker_config_files/fpm-pool.conf /etc/php/7.2/php-fpm.d/www.conf
#COPY ./docker_config_files//php.ini /etc/php7/conf.d/custom.ini

# Configure supervisord
COPY ./docker_config_files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Setup document root
RUN mkdir -p /home/tmo/src

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /home/tmo/src && \
  chown -R nobody.nobody /run && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /var/log/nginx

# Switch to use a non-root user from here on
USER root
ARG UID
RUN adduser -S tmo -u $UID
RUN addgroup tmo www-data
RUN addgroup tmo nobody
RUN addgroup tmo non-root
RUN cd /home/tmo
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer 
RUN apk add --update nodejs npm


# Add application		
WORKDIR /home/tmo/src

COPY --chown=nobody ./ /home/tmo/src


# Run composer create project for laravel 5.4
RUN composer create-project --prefer-dist laravel/laravel project "5.4.*"

# Run Composer install
RUN composer install

# Run npm install
RUN npm install

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping