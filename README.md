# NAS Config Backup

Backs up a NAS configuration directory to Google Drive on a nightly schedule using `rclone`. Backups are organized into daily, weekly (Sundays), and monthly (1st of month) folders with automatic pruning of old copies. Errors are logged and optionally pushed as Pushover notifications.

## Prerequisites

- `rclone` (configured with a Google Drive remote)
- `zip`
- `curl`

## Configuration

All configuration is supplied via environment variables, sourced from `/etc/nas-backup.env` by the systemd service.

1. Copy the example file and fill in your values:
   ```sh
   sudo cp nas-backup.env.example /etc/nas-backup.env
   sudo chmod 600 /etc/nas-backup.env
   sudo nano /etc/nas-backup.env
   ```

2. Required variables:
   - `NAS_CONFIG_DIR` — absolute path to the directory to back up
   - `GDRIVE_DEST` — rclone destination (e.g. `gdrive:backups`)

3. Optional variables (for Pushover failure alerts):
   - `PUSHOVER_TOKEN`
   - `PUSHOVER_USER`

## Deployment

```sh
# Install the script
sudo cp nas-backup.sh /usr/local/bin/nas-backup.sh
sudo chmod 755 /usr/local/bin/nas-backup.sh

# Install the systemd units (update ExecStart path in the service if needed)
sudo cp nas-backup.service nas-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload

# Enable and start the nightly timer
sudo systemctl enable --now nas-backup.timer
```

## Backup Retention

| Tier    | Frequency         | Pruned after |
|---------|-------------------|--------------|
| Daily   | Every run         | 7 days       |
| Weekly  | Sundays           | 28 days      |
| Monthly | 1st of each month | Never        |

## Logs

Errors are written to `~/nas-backup.log`.

## Manual Run

```sh
sudo systemctl start nas-backup
```
