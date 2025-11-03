resource "aws_ebs_volume" "prometheus_data" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 50 # Comece com 50GB
  type              = "gp3" # gp3 é mais barato e performático

  tags = {
    Name = "${var.project_name}-prometheus-data"
  }
}

resource "aws_volume_attachment" "prometheus_attach" {
  device_name = var.ebs_device_name
  volume_id   = aws_ebs_volume.prometheus_data.id
  instance_id = aws_instance.monitoring_server.id
}