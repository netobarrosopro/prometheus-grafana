#!/bin/bash
set -e # Aborta o script se houver erro

# Variáveis injetadas pelo Terraform
AWS_REGION="${aws_region}"
ECS_CLUSTER_NAME="${ecs_cluster_name}"
ECS_SERVICE_NAME="${ecs_service_name}"
DEVICE_PATH="${ebs_device_name}" # Ex: /dev/xvdh
MOUNT_POINT="/data"             # Ponto de montagem para todos os dados

# --- 1. Instalar Pacotes ---
yum update -y
amazon-linux-extras install docker -y
service docker start
usermod -a -G docker ec2-user
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# --- 2. Lógica de Montagem do EBS ---
echo "Esperando pelo volume EBS em ${DEVICE_PATH}..."
while [ ! -b "${DEVICE_PATH}" ]; do
  sleep 2
done
echo "Volume encontrado!"

# Verificar se o disco já está formatado
if ! file -s "${DEVICE_PATH}" | grep -q "filesystem"; then
  echo "Formatando o volume ${DEVICE_PATH}..."
  mkfs.ext4 "${DEVICE_PATH}"
fi

# Montar o volume
mkdir -p "${MOUNT_POINT}"
mount "${DEVICE_PATH}" "${MOUNT_POINT}"

# Adicionar ao /etc/fstab para montagem automática no boot
UUID=$(blkid -s UUID -o value "${DEVICE_PATH}")
echo "UUID=${UUID}  ${MOUNT_POINT}  ext4  defaults,nofail  0  0" >> /etc/fstab

# --- 3. Estrutura de Diretórios no Volume EBS ---
# Todo o estado e configuração viverão no volume persistente
BASE_DIR="${MOUNT_POINT}/monitoring"
mkdir -p "${BASE_DIR}/prometheus/data"
mkdir -p "${BASE_DIR}/grafana/data"
mkdir -p "${BASE_DIR}/grafana/provisioning/datasources"

# --- 4. Gerar Arquivos de Configuração ---

# docker-compose.yml
cat <<EOF > "${BASE_DIR}/docker-compose.yml"
version: '3.7'

services:
  prometheus:
    image: prom/prometheus:v2.47.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:10.1.5
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin # !! Mude isso em produção !!
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:v1.7.0
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
    restart: unless-stopped
EOF

# prometheus.yml
cat <<EOF > "${BASE_DIR}/prometheus/prometheus.yml"
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'ec2-host'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'ecs-n8n'
    ecs_sd_configs:
      - region: '${AWS_REGION}'
    
    relabel_configs:
      - source_labels: [__meta_ecs_cluster_name]
        regex: '${ECS_CLUSTER_NAME}'
        action: keep
      
      - source_labels: [__meta_ecs_service_name]
        regex: '${ECS_SERVICE_NAME}'
        action: keep
      
      - source_labels: [__meta_ecs_task_health_status]
        regex: 'RUNNING'
        action: keep

      - source_labels: [__meta_ecs_task_private_ip, __meta_ecs_task_container_port]
        regex: '([0-9\.]+):([0-9]+)'
        separator: ':'
        target_label: __address__
        action: replace

      - source_labels: []
        target_label: __metrics_path__
        replacement: /metrics
        action: replace
EOF

# grafana-datasource.yml
cat <<EOF > "${BASE_DIR}/grafana/provisioning/datasources/prometheus.yml"
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  url: http://prometheus:9090
  access: proxy
  isDefault: true
  editable: false
EOF

# --- 5. Ajustar Permissões e Iniciar o Stack ---
chown -R ec2-user:ec2-user "${MOUNT_POINT}"
chmod -R 775 "${BASE_DIR}/prometheus/data"
chmod -R 775 "${BASE_DIR}/grafana/data"

echo "Iniciando o stack de monitoramento via Docker Compose..."
docker-compose -f "${BASE_DIR}/docker-compose.yml" up -d