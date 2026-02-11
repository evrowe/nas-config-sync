#!/bin/bash
set -euo pipefail

LOG_FILE="$HOME/nas-backup.log"
LOCK_FILE="/tmp/nas-backup.lock"

if [[ -z "${NAS_CONFIG_DIR:-}" || -z "${GDRIVE_DEST:-}" ]]; then
    echo "Error: NAS_CONFIG_DIR and GDRIVE_DEST must be set as environment variables" >&2
    echo "Configure these in /etc/nas-backup.env (see nas-backup.env.example)" >&2
    exit 1
fi

for cmd in rclone zip curl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed or not in PATH" >&2
        exit 1
    fi
done

if [[ ! -d "$NAS_CONFIG_DIR" ]]; then
    echo "Error: Source directory does not exist: $NAS_CONFIG_DIR" >&2
    exit 1
fi

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_FILE"
}

notify_error() {
    if [[ -n "$PUSHOVER_TOKEN" && -n "$PUSHOVER_USER" ]]; then
        curl -s -o /dev/null \
            --form-string "token=$PUSHOVER_TOKEN" \
            --form-string "user=$PUSHOVER_USER" \
            --form-string "message=NAS config backup failed, see error log for details" \
            https://api.pushover.net/1/messages.json || true
    fi
}

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log_error "Backup already in progress, skipping"
    notify_error
    exit 1
fi

BACKUP_FILE="/tmp/$(date '+%Y-%m-%d')_backup.zip"
trap 'rm -f "$BACKUP_FILE"' EXIT

if ! zip -r -q "$BACKUP_FILE" "$NAS_CONFIG_DIR" 2>> "$LOG_FILE"; then
    log_error "Archive creation failed: $NAS_CONFIG_DIR -> $BACKUP_FILE"
    notify_error
    exit 1
fi

BACKUP_NAME="$(basename "$BACKUP_FILE")"

if ! rclone copyto "$BACKUP_FILE" "$GDRIVE_DEST/daily/$BACKUP_NAME" 2>> "$LOG_FILE"; then
    log_error "Upload failed: $BACKUP_FILE -> $GDRIVE_DEST/daily/"
    notify_error
    exit 1
fi

if [[ "$(date +%u)" -eq 7 ]]; then
    if ! rclone copyto "$BACKUP_FILE" "$GDRIVE_DEST/weekly/$BACKUP_NAME" 2>> "$LOG_FILE"; then
        log_error "Upload failed: $BACKUP_FILE -> $GDRIVE_DEST/weekly/"
        notify_error
        exit 1
    fi
fi

if [[ "$(date +%d)" == "01" ]]; then
    if ! rclone copyto "$BACKUP_FILE" "$GDRIVE_DEST/monthly/$BACKUP_NAME" 2>> "$LOG_FILE"; then
        log_error "Upload failed: $BACKUP_FILE -> $GDRIVE_DEST/monthly/"
        notify_error
        exit 1
    fi
fi

# Prune old backups
rclone delete --min-age 7d "$GDRIVE_DEST/daily/" 2>> "$LOG_FILE" || log_error "Prune failed: daily/"
rclone delete --min-age 28d "$GDRIVE_DEST/weekly/" 2>> "$LOG_FILE" || log_error "Prune failed: weekly/"
