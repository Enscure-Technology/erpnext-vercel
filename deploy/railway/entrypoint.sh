#!/usr/bin/env bash
set -euo pipefail

: "${DB_HOST:?DB_HOST required}"
: "${DB_PORT:=3306}"
: "${DB_ROOT_USER:=root}"
: "${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD required}"
: "${REDIS_HOST:?REDIS_HOST required}"
: "${REDIS_PORT:=6379}"
: "${SITE_NAME:?SITE_NAME required}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD required}"
: "${PORT:=8080}"

export SITE_NAME PORT

BENCH=/home/frappe/frappe-bench
SITES_DIR="$BENCH/sites"
SITES_INIT=/opt/frappe-sites-init

# Seed the sites volume from the image's pre-built defaults if empty.
if [[ ! -f "$SITES_DIR/apps.txt" ]]; then
    echo "[entrypoint] seeding empty sites volume from image defaults..."
    cp -a "$SITES_INIT/." "$SITES_DIR/"
    chown -R frappe:frappe "$SITES_DIR"
fi

# Render nginx config with PORT and SITE_NAME substituted.
envsubst '${PORT} ${SITE_NAME}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "[entrypoint] waiting for MariaDB at ${DB_HOST}:${DB_PORT}..."
for i in {1..60}; do
    if nc -z "$DB_HOST" "$DB_PORT"; then break; fi
    sleep 2
done

echo "[entrypoint] waiting for Redis at ${REDIS_HOST}:${REDIS_PORT}..."
for i in {1..60}; do
    if nc -z "$REDIS_HOST" "$REDIS_PORT"; then break; fi
    sleep 2
done

REDIS_BASE="redis://${REDIS_HOST}:${REDIS_PORT}"

# Write common_site_config.json — the single source of truth for Frappe.
install -d -o frappe -g frappe "$SITES_DIR"
cat > "$SITES_DIR/common_site_config.json" <<EOF
{
  "db_host": "${DB_HOST}",
  "db_port": ${DB_PORT},
  "redis_cache": "${REDIS_BASE}/0",
  "redis_queue": "${REDIS_BASE}/1",
  "redis_socketio": "${REDIS_BASE}/2",
  "socketio_port": 9000,
  "webserver_port": 8000,
  "background_workers": 1,
  "file_watcher_port": 6787,
  "serve_default_site": true,
  "developer_mode": 0,
  "maintenance_mode": 0
}
EOF
chown frappe:frappe "$SITES_DIR/common_site_config.json"

# Create the site on first boot.
if [[ ! -d "$SITES_DIR/$SITE_NAME" ]]; then
    echo "[entrypoint] creating site ${SITE_NAME}..."
    su frappe -c "cd $BENCH && bench new-site \
        --mariadb-user-host-login-scope='%' \
        --db-root-username='${DB_ROOT_USER}' \
        --db-root-password='${DB_ROOT_PASSWORD}' \
        --admin-password='${ADMIN_PASSWORD}' \
        --install-app erpnext \
        --set-default \
        '${SITE_NAME}'"
fi

# Always apply any pending migrations on boot.
echo "[entrypoint] running migrate..."
su frappe -c "cd $BENCH && bench --site ${SITE_NAME} migrate" || true

exec "$@"
