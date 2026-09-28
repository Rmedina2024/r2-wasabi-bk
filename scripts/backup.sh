#!/bin/bash

set -e
set -o pipefail

# Variables
TIMESTAMP=$(date +%Y-%m-%d)
LOG_FILE="/tmp/backup-${TIMESTAMP}.log"
FAILED_BUCKETS=""
SUCCESS_COUNT=0
FAILED_COUNT=0

{
    echo "=========================================="
    echo "Backup Report: ${TIMESTAMP}"
    echo "=========================================="
    echo ""

    # Descubrir todos los buckets en R2
    echo "[*] Descubriendo buckets en R2..."
    BUCKETS=$(rclone lsjson --dirs-only r2: | jq -r '.[].Name')

    if [ -z "$BUCKETS" ]; then
        echo "[ERROR] No se encontraron buckets en R2"
        exit 1
    fi

    BUCKET_COUNT=$(echo "$BUCKETS" | wc -l)
    echo "[✓] Se encontraron ${BUCKET_COUNT} buckets en R2"
    echo ""

    # Por cada bucket, crear sincronización
    for bucket in $BUCKETS; do
        echo "---"
        echo "Procesando bucket: $bucket"
        
        BACKUP_PATH="wasabi:${WASABI_BUCKET}/${bucket}/${TIMESTAMP}"
        SOURCE="r2:${bucket}"
        
        echo "  Source: ${SOURCE}"
        echo "  Destination: ${BACKUP_PATH}"
        
        # Crear directorio destino con timestamp
        rclone mkdir "$BACKUP_PATH" 2>/dev/null || true
        
        # Sincronizar
        if rclone sync "$SOURCE" "$BACKUP_PATH" \
            --transfers 4 \
            --checkers 8 \
            --delete-during \
            --progress \
            --log-level INFO 2>&1 | tee -a "$LOG_FILE"; then
            
            # Verificar integridad
            echo "  [*] Verificando integridad..."
            if rclone check "$SOURCE" "$BACKUP_PATH" --one-way 2>&1 | tee -a "$LOG_FILE"; then
                echo "  [✓] Backup exitoso"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                echo "  [⚠] Advertencia en verificación"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        else
            echo "  [ERROR] Fallo en la sincronización"
            FAILED_BUCKETS="${FAILED_BUCKETS}${bucket}, "
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
        
        echo ""
    done

    echo "=========================================="
    echo "RESUMEN"
    echo "=========================================="
    echo "Total buckets: ${BUCKET_COUNT}"
    echo "Exitosos: ${SUCCESS_COUNT}"
    echo "Fallidos: ${FAILED_COUNT}"
    
    if [ ! -z "$FAILED_BUCKETS" ]; then
        echo "Buckets con error: ${FAILED_BUCKETS}"
    fi
    
    echo "Fecha: $(date)"
    echo "=========================================="

} | tee "$LOG_FILE"

# Subir log a S3 para referencia
echo "[*] Guardando log en S3..."
aws s3 cp "$LOG_FILE" "s3://s3-backups-buckets-r2/logs/backup-${TIMESTAMP}.log" || true

# Si hubo fallos, salir con error (para alertas)
if [ $FAILED_COUNT -gt 0 ]; then
    exit 1
fi

exit 0