variable "aws_region" {
  description = "Região da AWS para implantar os recursos."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto para usar em tags."
  type        = string
  default     = "monitoring"
}

variable "instance_type" {
  description = "Tipo da instância EC2 para o servidor de monitoramento."
  type        = string
  default     = "c7i-flex.large" # Prometheus e Grafana podem consumir bastante RAM
}

variable "my_ip" {
  description = "Seu endereço IP (CIDR) para acesso SSH, Grafana (3000) e Prometheus (9090)."
  type        = string
  # IMPORTANTE: Troque pelo seu IP. Use "0.0.0.0/0" apenas para testes rápidos.
  default = "0.0.0.0/0"
}

variable "ebs_device_name" {
  description = "Nome do dispositivo para o volume EBS persistente."
  type        = string
  default     = "/dev/xvdf"
}

variable "aws_key_pair_name" {
  description = "projeto_gb"
  type        = string
  default     = null # Usamos 'null' para tornar opcional
}