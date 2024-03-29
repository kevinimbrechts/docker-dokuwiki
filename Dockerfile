#################################
###        PHP-FPM 8.0        ###
###        ALPINE 3.14        ###
###    DOKUWIKI 2018-04-22b   ###
#################################

FROM php:7.4.26-fpm-alpine3.15
LABEL maintainer="Kevin Imbrechts <imbrechts.kevin@protonmail.com>"

ARG user="www-data"
ARG group="www-data"
ARG http_port=8080
ARG https_port=4443
ARG doku_file="/tmp/dokuwiki.tar.gz"

ENV LASTREFRESH="20211202" \
    DOKU_VER="2020-07-29" \
    DOKU_MD5="8867b6a5d71ecb5203402fe5e8fa18c9" \
    # PHP ENV
    PHP_FPM_USER=${user} \
    PHP_FPM_GROUP=${group} \
    PHP_FPM_LISTEN_MODE="0660" \
    PHP_MEMORY_LIMIT="512M" \
    PHP_MAX_UPLOAD="50M" \
    PHP_MAX_FILE_UPLOAD="200" \
    PHP_MAX_POST="100M" \
    PHP_DISPLAY_ERRORS="On" \
    PHP_DISPLAY_STARTUP_ERRORS="On" \
    PHP_ERROR_REPORTING="E_COMPILE_ERROR\|E_RECOVERABLE_ERROR\|E_ERROR\|E_CORE_ERROR" \
    PHP_CGI_FIX_PATHINFO=0 \
    PHP_FPM_LISTEN="/opt/run/php/php-fpm.sock"

WORKDIR /var/www/html/dokuwiki

# Global installation
RUN set -x && \
    apk update && \
    apk add --no-cache --virtual mypack \
            curl=7.80.0-r0 \
            gzip=1.11-r0 \
            libpng-dev=1.6.37-r1 \
            jpeg-dev=9d-r1 \
            nginx=1.20.2-r0 \
            supervisor=4.2.2-r2 \
            shadow=4.8.1-r1 \
            tar=1.34-r0 && \
    docker-php-ext-configure gd --with-jpeg && \
    docker-php-ext-install gd

RUN usermod -u 1000 www-data && \
    groupmod -g 1000 www-data && \
    apk del shadow

# Timezone
RUN ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime && \
    echo "Europe/Paris" > /etc/timezone

# Dokuwiki install
RUN curl -fSL https://download.dokuwiki.org/src/dokuwiki/dokuwiki-${DOKU_VER}.tgz \
         -o ${doku_file}

# Add pipefail for md5sum and check md5
RUN apk add bash bash-doc bash-completion
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo "${DOKU_MD5}  ${doku_file}" | md5sum -c && \
    tar -xz --strip-components=1 -f ${doku_file}

# PHP & NginX config
RUN ln -s /usr/local/etc /etc/php && \
    rm -f /etc/nginx/http.d/default.conf && \
    rm -f /etc/php/php-fpm.d/www.conf.default && \
    rm -f /etc/php/php-fpm.conf.default

# PHP Config
RUN mv /etc/php/php/php.ini-production /etc/php/php/php.ini && \
    sed -i "s|display_errors\s*=\s*Off|display_errors=${PHP_DISPLAY_ERRORS}|i" /etc/php/php/php.ini && \
    sed -i "s|display_startup_errors\s*=\s*Off|display_startup_errors=${PHP_DISPLAY_STARTUP_ERRORS}|i" /etc/php/php/php.ini && \
    sed -i "s|error_reporting\s*=\s*E_ALL & ~E_DEPRECATED & ~E_STRICT|error_reporting=${PHP_ERROR_REPORTING}|i" /etc/php/php/php.ini && \
    sed -i "s|;*memory_limit =.*|memory_limit=${PHP_MEMORY_LIMIT}|i" /etc/php/php/php.ini && \
    sed -i "s|;*upload_max_filesize =.*|upload_max_filesize=${PHP_MAX_UPLOAD}|i" /etc/php/php/php.ini && \
    sed -i "s|;*max_file_uploads =.*|max_file_uploads=${PHP_MAX_FILE_UPLOAD}|i" /etc/php/php/php.ini && \
    sed -i "s|;*post_max_size =.*|post_max_size=${PHP_MAX_POST}|i" /etc/php/php/php.ini && \
    sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo=${PHP_CGI_FIX_PATHINFO}|i" /etc/php/php/php.ini

# Create dir & perms
RUN mkdir -p /opt/run/php && \
    mkdir /opt/run/nginx/ && \
    mkdir -p /var/lib/nginx/logs/ && \
    mkdir /etc/letsencrypt && \
    # For "/var/tmp/nginx/client_body"
    mkdir -p /var/tmp/nginx/ && \
    chown -R www-data:www-data . && \
    chown -R www-data:www-data /var/log && \
    chown -R www-data:www-data /opt/run/ && \
    chown -R www-data:www-data /var/tmp && \
    chown -R www-data:www-data /var/lib/nginx && \
    chown -R www-data:www-data /etc/letsencrypt

# Cleanup
RUN rm ${doku_file} && \
    apk del tar gzip curl && \
    rm /usr/local/etc/php/php.ini-development

COPY etc/php/php-fpm.d/www.conf /etc/php/php-fpm.d/
COPY etc/php/php-fpm.d/zz-docker.conf /etc/php/php-fpm.d/
COPY etc/php/php-fpm.conf /etc/php/php-fpm.conf
COPY etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY etc/nginx/http.d/ /etc/nginx/http.d/
COPY etc/supervisord.conf /etc/supervisord.conf
COPY etc/supervisor/conf.d/* /etc/supervisor/conf.d/

EXPOSE ${http_port}
EXPOSE ${https_port}

USER ${user}

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
