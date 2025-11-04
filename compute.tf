# Busca a AMI mais recente do Amazon Linux 2
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# A instância EC2 principal
resource "aws_instance" "monitoring_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  #Key para acesso
  key_name = var.aws_key_pair_name

  subnet_id                   = aws_subnet.monitoring_subnet.id
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.monitoring_profile.name
  associate_public_ip_address = true

  # variáveis para o script de template
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    EBS_DEVICE   = var.ebs_device_name,
    AWS_REGION   = var.aws_region
  })

  # Evitar que o user_data rode em cada 'apply'
  user_data_replace_on_change = false

  tags = {
    Name = "${var.project_name}-server"
  }
}