#!/bin/bash

set -e

# Variables
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO_NAME="rclone-r2-wasabi-backup"
IMAGE_TAG="latest"

echo "=========================================="
echo "Build & Push to ECR"
echo "=========================================="
echo "Region: ${AWS_REGION}"
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Repository: ${ECR_REPO_NAME}"
echo ""

# Crear repositorio ECR si no existe
echo "[*] Verificando ECR repository..."
if ! aws ecr describe-repositories \
    --repository-names "${ECR_REPO_NAME}" \
    --region "${AWS_REGION}" 2>/dev/null; then
    
    echo "[*] Creando repositorio ECR..."
    aws ecr create-repository \
    --repository-name "${ECR_REPO_NAME}" \
    --region "${AWS_REGION}" \
    --image-scanning-configuration scanOnPush=true
    
    echo "[✓] Repositorio creado"
else
    echo "[✓] Repositorio ya existe"
fi

echo ""

# Login a ECR
   echo "[*] Login a ECR..."
   aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin \
    "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" 2>/dev/null || echo "[!] Login warning (continuando...)"

echo ""

# Build
echo "[*] Construyendo imagen Docker..."
docker build -t "${ECR_REPO_NAME}:${IMAGE_TAG}" .

echo ""

# Tag para ECR
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}"
echo "[*] Tagging imagen: ${ECR_URI}"
docker tag "${ECR_REPO_NAME}:${IMAGE_TAG}" "${ECR_URI}"

echo ""

# Push
echo "[*] Pushing a ECR..."
docker push "${ECR_URI}"

echo ""
echo "=========================================="
echo "[✓] Build completado!"
echo "=========================================="
echo "Imagen: ${ECR_URI}"
echo "=========================================="
