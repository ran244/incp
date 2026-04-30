#!/bin/bash
set -e

DB_PW_FILE="/run/secrets/db_password"
WP_ADMIN_PW_FILE="/run/secrets/wp_admin_password"
WP_USER_PW_FILE="/run/secrets/wp_user_password"

# Read passwords from secret files
DB_PASSWORD="$(tr -d '\n' < "$DB_PW_FILE")"
WP_ADMIN_PASSWORD="$(tr -d '\n' < "$WP_ADMIN_PW_FILE")"
WP_USER_PASSWORD="$(tr -d '\n' < "$WP_USER_PW_FILE")"

# Wait for MariaDB to be ready
echo "Waiting for MariaDB..."
until mariadb \
  --protocol=TCP \
  --host="${DB_HOST}" \
  --user="${MYSQL_USER}" \
  --password="${DB_PASSWORD}" \
  --skip-ssl \
  --execute="SELECT 1;" >/dev/null 2>&1; do
  echo "Not ready yet, retrying in 2s..."
  sleep 2
done
echo "MariaDB is ready!"

cd /var/www/html

# Download WP-CLI if not present
if [ ! -f "/usr/local/bin/wp" ]; then
  curl -sSLo /usr/local/bin/wp \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /usr/local/bin/wp
fi

# Download WordPress core if not present
if [ ! -f "wp-settings.php" ]; then
  echo "Downloading WordPress..."
  wp core download --allow-root
fi

# Create config file if not present
if [ ! -f "wp-config.php" ]; then
  echo "Creating wp-config.php..."
  wp config create \
    --allow-root \
    --dbname="${MYSQL_DATABASE}" \
    --dbuser="${MYSQL_USER}" \
    --dbpass="${DB_PASSWORD}" \
    --dbhost="${DB_HOST}" \
    --skip-check
fi

# Install WordPress if not already installed
if ! wp core is-installed --allow-root >/dev/null 2>&1; then
  echo "Installing WordPress..."
  wp core install \
    --allow-root \
    --url="${WP_URL}" \
    --title="${WP_TITLE}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}"

  echo "Creating regular user..."
  wp user create \
    --allow-root \
    "${WP_USER}" "${WP_USER_EMAIL}" \
    --user_pass="${WP_USER_PASSWORD}"
else
  echo "WordPress already installed, skipping."
fi

# Fix PHP-FPM to listen on port 9000
sed -i 's|^listen = .*|listen = 9000|' /etc/php/*/fpm/pool.d/www.conf

# Start PHP-FPM in foreground
exec php-fpm8.2 -F
