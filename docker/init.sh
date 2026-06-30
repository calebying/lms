#!/bin/bash
set -e

PERSIST_DIR="/home/frappe/frappe-persist"
BENCH_DIR="/home/frappe/frappe-bench"

# Fast path: bench fully initialized and persisted
if [ -f "$PERSIST_DIR/Procfile" ]; then
    echo "=== Bench persisted - fast start ==="
    # Replace real dir with symlink so bench runs from the persisted volume
    if [ -d "$BENCH_DIR" ] && [ ! -L "$BENCH_DIR" ]; then
        rm -rf "$BENCH_DIR"
    fi
    ln -sfn "$PERSIST_DIR" "$BENCH_DIR"
    cd "$BENCH_DIR"
    exec bench start
fi

# Crash recovery: bench dir exists but persist is incomplete — clean up and retry
if [ -d "$BENCH_DIR" ]; then
    echo "=== Cleaning up incomplete bench from previous crashed run ==="
    rm -rf "$BENCH_DIR"
fi

echo "=== First run: initializing bench (~20 min) ==="
export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

bench init --skip-redis-config-generation frappe-bench
cd frappe-bench

bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

bench get-app --overwrite payments
bench get-app --overwrite lms

bench new-site lms.localhost \
  --force \
  --mariadb-root-password 123 \
  --admin-password admin \
  --no-mariadb-socket

# install-app triggers asset builds that may fail on the first attempt;
# app installation (DocTypes, migrations) succeeds — only the yarn build can fail
set +e
bench --site lms.localhost install-app payments
bench --site lms.localhost install-app lms
set -e

bench --site lms.localhost set-config developer_mode 1
bench --site lms.localhost clear-cache

# Explicit asset build — LMS Vite build may fail; non-fatal, app still works
echo "=== Building frontend assets ==="
bench build --production || echo "Asset build had errors (non-fatal, app will build on demand)"

echo "=== Persisting bench to volume for fast future starts ==="
cp -a . "$PERSIST_DIR/"

echo "=== Init complete - starting bench ==="
exec bench start
