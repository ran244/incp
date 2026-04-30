#!/bin/sh
set -eu

DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

DB_NAME="${MYSQL_DATABASE:-wordpress}"
DB_USER="${MYSQL_USER:-wpuser}"

# Secrets usually mounted by Docker Compose
ROOT_PW="$(cat /run/secrets/db_root_password)"
DB_PW="$(cat /run/secrets/db_password)"

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld "$DATADIR"

# --- ONLY RUN THIS IF DATABASE IS NOT INITIALIZED ---
if [ ! -f "$DATADIR/.setup_complete" ]; then
    echo "First boot detected. Initializing database..."
    
    # 1. Install base system tables
    mariadb-install-db --user=mysql --datadir="$DATADIR" >/dev/null

    # 2. Start MariaDB temporarily without networking to configure it
    mysqld --user=mysql --datadir="$DATADIR" --socket="$SOCKET" --skip-networking &
    pid="$!"

    # 3. Wait for it to wake up
    i=0
    while ! mariadb-admin --socket="$SOCKET" ping --silent >/dev/null 2>&1; do
        i=$((i+1))
        if [ "$i" -ge 30 ]; then
            echo "Timeout: MariaDB failed to start for setup."
            exit 1
        fi
        sleep 1
    done

    # 4. Run configuration (Root has no password yet here)
    echo "Configuring users and privileges..."
    mariadb --socket="$SOCKET" -u root <<-SQL
		CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
		CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PW';
		GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
		ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PW';
		FLUSH PRIVILEGES;
SQL

    # 5. Shut down temporary instance
    echo "Finalizing first-time setup..."
    mariadb-admin --socket="$SOCKET" -u root -p"$ROOT_PW" shutdown
    wait "$pid"
    
    # 6. Create the flag file so this block never runs again
    touch "$DATADIR/.setup_complete"
    echo "Setup finished successfully."
else
    echo "Database already initialized. Skipping setup."
fi

# --- START FINAL PROCESS ---
# This runs every time, whether it's the 1st boot or the 100th.
echo "Starting MariaDB on port 3306..."
exec mysqld \
  --user=mysql \
  --datadir="$DATADIR" \
  --bind-address=0.0.0.0 \
  --port=3306 \
  --skip-name-resolve