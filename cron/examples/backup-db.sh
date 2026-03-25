#!/bin/bash
# backup-db.sh - Database backup template
#
# Supports PostgreSQL (pg_dump) and SQLite (.backup command).
# Writes dated backup files, verifies non-empty, prunes old backups.
#
# Configuration via environment variables:
#   DB_TYPE           "postgres" or "sqlite" (required)
#   BACKUP_DIR        Directory to write backups to (required)
#   BACKUP_KEEP_DAYS  Number of days of backups to retain (default: 7)
#   LOG_FILE          Log file path (default: /var/log/backup-db.log)
#
# PostgreSQL-specific:
#   PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE  (standard pg env vars)
#
# SQLite-specific:
#   SQLITE_DB_PATH    Path to the SQLite database file (required for sqlite)

set -euo pipefail

DB_TYPE="${DB_TYPE:?DB_TYPE env var is required (postgres or sqlite)}"
BACKUP_DIR="${BACKUP_DIR:?BACKUP_DIR env var is required}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"
LOG_FILE="${LOG_FILE:-/var/log/backup-db.log}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

mkdir -p "$BACKUP_DIR"

case "$DB_TYPE" in
  postgres)
    PGDATABASE="${PGDATABASE:?PGDATABASE env var is required for postgres}"
    BACKUP_FILE="${BACKUP_DIR}/${PGDATABASE}_${TIMESTAMP}.sql.gz"
    log "Starting PostgreSQL backup: $PGDATABASE -> $BACKUP_FILE"
    pg_dump \
      --no-password \
      --format=plain \
      "$PGDATABASE" | gzip > "$BACKUP_FILE"
    ;;

  sqlite)
    SQLITE_DB_PATH="${SQLITE_DB_PATH:?SQLITE_DB_PATH env var is required for sqlite}"
    DB_NAME=$(basename "$SQLITE_DB_PATH" .sqlite)
    BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sqlite"
    log "Starting SQLite backup: $SQLITE_DB_PATH -> $BACKUP_FILE"
    # Use .backup for a safe online copy (WAL-safe, no lock needed)
    sqlite3 "$SQLITE_DB_PATH" ".backup '${BACKUP_FILE}'"
    ;;

  *)
    log "ERROR: Unknown DB_TYPE '$DB_TYPE'. Expected 'postgres' or 'sqlite'."
    exit 1
    ;;
esac

# Verify backup is non-empty
if [ ! -s "$BACKUP_FILE" ]; then
  log "ERROR: Backup file is empty: $BACKUP_FILE"
  exit 1
fi

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Backup OK: $BACKUP_FILE ($SIZE)"

# Prune backups older than KEEP_DAYS
PRUNED=0
while IFS= read -r old_file; do
  log "Pruning old backup: $old_file"
  rm -f "$old_file"
  PRUNED=$((PRUNED + 1))
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.sql.gz" -o -name "*.sqlite" \) -mtime "+${KEEP_DAYS}")

log "Pruned $PRUNED old backup(s) (keep last ${KEEP_DAYS} days)"
log "Done."
