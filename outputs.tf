output "monitoring_server_public_ip" {
  description = "IP Público do servidor de Monitoramento"
  value       = aws_instance.monitoring_server.public_ip
}

output "prometheus_ui" {
  description = "URL da interface do Prometheus"
  value       = "http://${aws_instance.monitoring_server.public_ip}:9090"
}

output "grafana_ui" {
  description = "URL da interface do Grafana"
  value       = "http://${aws_instance.monitoring_server.public_ip}:3000"
}