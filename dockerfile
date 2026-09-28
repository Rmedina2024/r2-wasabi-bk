FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Bogota
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Instalar dependencias
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    python3 \
    python3-pip \
    unzip \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*


RUN curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws \
    && /usr/local/bin/aws --version

# Instalar rclone
RUN curl https://rclone.org/install.sh | bash

# Instalar boto3 para AWS S3
RUN pip3 install boto3

# Crear directorio de trabajo
WORKDIR /app

# Copiar scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Copiar entrypoint
COPY scripts/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
