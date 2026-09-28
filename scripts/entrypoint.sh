#!/bin/bash

set -e

echo "=========================================="
echo "R2 to Wasabi Backup - $(date)"
echo "=========================================="

# Cargar variables del .env en S3
echo "[*] Descargando configuración de S3..."
aws s3 cp s3://s3-backups-buckets-r2/.env /tmp/.env
source /tmp/.env

# Configurar rclone
echo "[*] Configurando rclone..."
mkdir -p ~/.config/rclone

cat > ~/.config/rclone/rclone.conf <<EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY}
secret_access_key = ${R2_SECRET_KEY}
endpoint = https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com

[wasabi]
type = s3
provider = Wasabi
access_key_id = ${WASABI_ACCESS_KEY}
secret_access_key = ${WASABI_SECRET_KEY}
endpoint = https://s3.${WASABI_REGION}.wasabisys.com
EOF

chmod 600 ~/.config/rclone/rclone.conf

# Ejecutar backup
echo "[*] Iniciando backup..."
/app/scripts/backup.sh

# Ejecutar limpieza de archivos >15 días
echo "[*] Limpiando archivos antiguos..."
python3 /app/scripts/cleanup.py

echo "[*] Backup completado exitosamente!"
echo "=========================================="