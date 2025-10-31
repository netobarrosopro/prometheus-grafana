# Busca a AMI mais recente do Amazon Linux 2
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 1. Cria o Volume EBS dedicado
resource "aws_ebs_volume" "monitoring_data" {
  availability_zone = var.availability_zone # DEVE ser a mesma AZ da EC2
  size              = var.ebs_volume_size
  type              = "gp3" # gp3 é mais moderno e custo-benefício que gp2

  tags = {
    Name = "Monitoring-Data-Volume"
  }

  # Melhor prática de produção: Proteger contra exclusão acidental
  lifecycle {
    prevent_destroy = true
  }
}

# 2. Cria a Instância EC2
resource "aws_instance" "monitoring_server" {
  ami               = data.aws_ami.amazon_linux_2.id
  instance_type     = var.instance_type
  availability_zone = var.availability_zone # Garante que está na mesma AZ do volume

  iam_instance_profile = aws_iam_instance_profile.monitoring_ec2_profile.name
  security_groups      = [aws_security_group.monitoring_sg.name]
  
  # O script de user_data agora recebe o nome do dispositivo EBS
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    aws_region       = var.aws_region,
    ecs_cluster_name = var.ecs_cluster_name,
    ecs_service_name = var.ecs_service_name,
    ebs_device_name  = "/dev/xvdh" # O nome que o OS verá (/dev/sdh -> /dev/xvdh)
  })

  tags = {
    Name = "Monitoring-Server (Prometheus+Grafana)"
  }
}

# 3. Anexa o Volume EBS à Instância
resource "aws_volume_attachment" "monitoring_data_attachment" {
  device_name = "/dev/sdh" # O nome que a AWS usa para anexar
  instance_id = aws_instance.monitoring_server.id
  volume_id   = aws_ebs_volume.monitoring_data.id

  # Garante que a instância existe antes de tentar anexar
  depends_on = [
    aws_instance.monitoring_server
  ]
}