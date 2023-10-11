FROM alpine:3.12 as build

RUN sed -i 's/dl-cdn.alpinelinux.org/ftp.halifax.rwth-aachen.de/g' /etc/apk/repositories \
 && apk add bash curl gd php7 php7-curl php7-gd php7-json php7-openssl php7-xml php7-pecl-imagick php7-pgsql php7-mysqli php7-mbstring php7-pecl-mcrypt php7-zip \
 && apk add git patch \
 && git clone https://framagit.org/hubzilla/core.git /hubzilla
WORKDIR /hubzilla
COPY entrypoint.sh /hubzilla
COPY .tags /tmp/
RUN sed 's/,.*//' /tmp/.tags >/hubzilla/version \
 && chmod +x /hubzilla/entrypoint.sh \
 && git pull \
 && git checkout tags/$(cat /hubzilla/version) \
 && rm -rf .git \
 && mkdir -p "store/[data]/smarty3" \
 && util/add_widget_repo https://framagit.org/hubzilla/widgets.git hubzilla-widgets \
 && util/add_addon_repo https://framagit.org/hubzilla/addons.git hzaddons \
 && util/add_addon_repo https://framagit.org/dentm42/dm42-hz-addons.git dm42

FROM php:7.4-fpm-alpine
RUN sed -i 's/dl-cdn.alpinelinux.org/ftp.halifax.rwth-aachen.de/g' /etc/apk/repositories \
 && apk --update --no-cache --no-progress add libpng imagemagick-libs libjpeg-turbo rsync ssmtp shadow mysql-client postgresql-client libmcrypt tzdata ssmtp bash git tzdata openldap-clients imagemagick oniguruma libzip \
 && apk --update --no-progress add --virtual build-deps autoconf curl-dev freetype-dev build-base  icu-dev libjpeg-turbo-dev imagemagick-dev libldap libmcrypt-dev libpng-dev libtool libxml2-dev openldap-dev postgresql-dev postgresql-libs unzip libmcrypt-dev libxml2-dev openldap-dev oniguruma-dev libzip-dev \
 && docker-php-ext-configure gd --enable-gd --with-jpeg --with-freetype \
 && docker-php-ext-install gd json mbstring mysqli pgsql xml zip curl json xml zip pdo pdo_mysql pdo_pgsql ldap opcache \
 && pecl install -o -f redis		\
 && docker-php-ext-enable redis.so	\
 && pecl install imagick                \
 && docker-php-ext-enable imagick       \
 && pecl install xhprof \
 && docker-php-ext-enable xhprof.so \
 && echo 'xhprof.output_dir = "/var/www/html/xhprof"'|tee -a /usr/local/etc/php/conf.d/docker-php-ext-xhprof.ini \
 && sed -i '/www-data/s#:[^:]*$#:/bin/ash#' /etc/passwd \
 && echo 'sendmail_path = "/usr/sbin/ssmtp -t"' > /usr/local/etc/php/conf.d/mail.ini \
 && echo -e 'upload_max_filesize = 100M\npost_max_size = 101M' > /usr/local/etc/php/conf.d/hubzilla.ini \
 && echo -e '#!/bin/sh\ncd /var/www/html\n/usr/local/bin/php /var/www/html/Zotlabs/Daemon/Master.php Cron' >/etc/periodic/15min/hubzilla \
 && chmod 755 /etc/periodic/15min/hubzilla \
 && apk --purge del build-deps		\
 && rm -rf /tmp/* /var/cache/apk/*gz
COPY --from=build /hubzilla /hubzilla

ENTRYPOINT [ "/hubzilla/entrypoint.sh" ]
CMD ["php-fpm"]
VOLUME /var/www/html
ENV SMTP_HOST ${SMTP_HOST}
ENV SMTP_PORT ${SMTP_PORT}
ENV SMTP_DOMAIN ${SMTP_DOMAIN}
ENV SMTP_USER ${SMTP_USER}
ENV SMTP_PASS ${SMTP_PASS}
ENV SMTP_USE_STARTTLS ${SMTP_USE_STARTTLS}
