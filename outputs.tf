output "monitoring_server_public_ip" {
  description = "IP público do servidor de monitoramento"
  value       = aws_instance.monitoring_server.public_ip
}

output "monitoring_server_id" {
  description = "ID da instância EC2 de monitoramento"
  value       = aws_instance.monitoring_server.id
}

output "ebs_volume_id" {
  description = "ID do volume EBS de dados"
  value       = aws_ebs_volume.monitoring_data.id
}