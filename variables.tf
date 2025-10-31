variable "aws_region" {
  description = "Região da AWS para os recursos"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Zona de Disponibilidade. Deve ser a mesma para a EC2 e o EBS."
  type        = string
  default     = "us-east-1a" # IMPORTANTE: Escolha uma AZ
}

variable "my_ip" {
  description = "Seu IP público para liberar acesso SSH e Grafana"
  type        = string
  sensitive   = true # Boa prática para IPs
  # Sem default, force o usuário a inserir:
  # terraform apply -var="my_ip=1.2.3.4/32"
}

variable "ecs_cluster_name" {
  description = "Nome do Cluster ECS onde o n8n está"
  type        = string
}

variable "ecs_service_name" {
  description = "Nome do Serviço ECS do n8n"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instância EC2 para o servidor de monitoramento"
  type        = string
  default     = "t3.small" # t3.micro pode ser pouco para Prome+Grafana
}

variable "ebs_volume_size" {
  description = "Tamanho em GiB do volume EBS para dados (Prometheus/Grafana)"
  type        = number
  default     = 20 # Comece com 20GB e monitore
}