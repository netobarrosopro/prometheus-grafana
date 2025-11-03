#!/bin/bash
set -e # Aborta o script se qualquer comando falhar

# 1. Instalação do Docker
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# 2. Preparação do Volume EBS
# Espera o volume estar disponível
while [ ! -e ${EBS_DEVICE} ]; do
  echo "Aguardando o volume ${EBS_DEVICE}..."
  sleep 5
done

# Formata o volume (apenas se não estiver formatado)
if [ -z "$(file -s ${EBS_DEVICE} | grep ext4)" ]; then
  mkfs -t ext4 ${EBS_DEVICE}
fi

# Cria diretórios para os dados
mkdir -p /data/prometheus
mkdir -p /data/grafana

# Monta o volume
mount ${EBS_DEVICE} /data
echo "${EBS_DEVICE} /data ext4 defaults,nofail 0 2" >> /etc/fstab

# Define permissões corretas para os contêineres
# Prometheus (nobody:nobody) e Grafana (grafana:grafana)
chown -R 65534:65534 /data/prometheus
chown -R 472:472 /data/grafana

# 3. Criação dos Arquivos de Configuração
mkdir -p /opt/prometheus

# 3a. Configuração do CloudWatch Exporter (config.yml)
# Monitora EC2 (avg/max por 5m) e RDS
cat <<EOF > /opt/prometheus/cloudwatch_exporter.yml
---
region: ${AWS_REGION}
metrics:
- aws_namespace: AWS/EC2
  aws_metric_name: CPUUtilization
  aws_dimensions: [InstanceId]
  aws_statistics: [Average, Maximum]
- aws_namespace: AWS/RDS
  aws_metric_name: CPUUtilization
  aws_dimensions: [DBInstanceIdentifier]
  aws_statistics: [Average]
- aws_namespace: AWS/RDS
  aws_metric_name: DatabaseConnections
  aws_dimensions: [DBInstanceIdentifier]
  aws_statistics: [Average]
EOF

# 3b. Configuração do Prometheus (prometheus.yml)
cat <<EOF > /opt/prometheus/prometheus.yml
global:
  scrape_interval: 1m # Coleta a cada 1 minuto

scrape_configs:
  - job_name: 'prometheus'
    # Coleta métricas do próprio Prometheus
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cloudwatch_exporter'
    # Coleta métricas do CloudWatch Exporter
    static_configs:
      - targets: ['localhost:9106']
EOF

# 4. Inicia os Contêineres Docker
# 4a. CloudWatch Exporter
docker run -d \
  --name cloudwatch-exporter \
  --restart=always \
  -p 9106:9106 \
  -v /opt/prometheus/cloudwatch_exporter.yml:/config/config.yml \
  prom/cloudwatch-exporter:v0.19.0 \
  --config.file=/config/config.yml

# 4b. Prometheus
docker run -d \
  --name prometheus \
  --restart=always \
  -p 9090:9090 \
  -v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v /data/prometheus:/prometheus \
  prom/prometheus:v2.51.0 \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.enable-lifecycle # Permite recarregar config via API

# 4c. Grafana
docker run -d \
  --name grafana \
  --restart=always \
  -p 3000:3000 \
  -v /data/grafana:/var/lib/grafana \
  grafana/grafana:10.4.1

echo "Configuração concluída com sucesso!"