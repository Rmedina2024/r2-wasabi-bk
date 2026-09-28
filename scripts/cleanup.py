#!/usr/bin/env python3

import subprocess
import json
import os
from datetime import datetime, timedelta

# Variables de entorno
WASABI_BUCKET = os.getenv('WASABI_BUCKET', 's3-backups-r2')
RETENTION_DAYS = 15

print(f"[*] Limpiando backups más antiguos de {RETENTION_DAYS} días en {WASABI_BUCKET}")
print("=" * 50)

# Obtener fecha límite
cutoff_date = (datetime.now() - timedelta(days=RETENTION_DAYS)).date()
print(f"[*] Eliminaré archivos anteriores a: {cutoff_date}")
print()

try:
    # Listar todos los archivos en Wasabi
    print("[*] Listando archivos en Wasabi...")
    result = subprocess.run(
           ['rclone', 'lsjson', '--recursive', '--files-only',  f'wasabi:{WASABI_BUCKET}'],
        capture_output=True,
        text=True,
        check=True
    )
    
    files = json.loads(result.stdout) if result.stdout else []
    
    if not files:
        print("[*] No hay archivos en Wasabi")
        exit(0)
    
    deleted_count = 0
    skipped_count = 0
    deleted_size = 0
    
    print(f"[*] Procesando {len(files)} archivos...")
    print()
    
    for file_info in files:
        file_path = file_info['Path']
        file_size = file_info['Size']
        
        # Extraer fecha del path (formato: bucket/2026-09-21/...)
        parts = file_path.split('/')
        if len(parts) >= 2:
            try:
                date_str = parts[1]  # Asume formato YYYY-MM-DD
                file_date = datetime.strptime(date_str, '%Y-%m-%d').date()
                
                # Si es más antiguo que la fecha límite, eliminar
                if file_date < cutoff_date:
                    print(f"  [X] Eliminando: {file_path} (fecha: {file_date})")
                    
                    subprocess.run(
                        ['rclone', 'delete', f'wasabi:{WASABI_BUCKET}/{file_path}'],
                        check=True,
                        capture_output=True
                    )
                    
                    deleted_count += 1
                    deleted_size += file_size
                else:
                    skipped_count += 1
                    
            except ValueError:
                # Si no puede parsear la fecha, mantener el archivo
                skipped_count += 1
        else:
            skipped_count += 1
    
    print()
    print("=" * 50)
    print("RESUMEN LIMPIEZA")
    print("=" * 50)
    print(f"Archivos eliminados: {deleted_count}")
    print(f"Archivos mantenidos: {skipped_count}")
    print(f"Espacio liberado: {deleted_size / (1024**3):.2f} GB")
    print(f"Fecha de corte: {cutoff_date}")
    print(f"Timestamp: {datetime.now()}")
    print("=" * 50)

except subprocess.CalledProcessError as e:
    print(f"[ERROR] Fallo en operación rclone: {e.stderr}")
    exit(1)
except json.JSONDecodeError:
    print("[ERROR] Error al parsear JSON de rclone")
    exit(1)
except Exception as e:
    print(f"[ERROR] {str(e)}")
    exit(1)

print("[✓] Limpieza completada")
