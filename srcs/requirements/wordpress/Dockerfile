FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    php-fpm php-mysql mariadb-client curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/php /var/www/html

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
