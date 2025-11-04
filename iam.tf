# IAM Role para a EC2
resource "aws_iam_role" "monitoring_role" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# Política de permissões
# Esta política dá ao Cloudwatch Exporter acesso de leitura
resource "aws_iam_policy" "monitoring_policy" {
  name        = "${var.project_name}-read-policy"
  description = "Permite ler métricas do CloudWatch e descrever recursos"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "tag:GetResources"
        ],
        Resource = "*"
      }
      
    ]
  })
}

# Anexar a Política à Role
resource "aws_iam_role_policy_attachment" "monitoring_attach" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = aws_iam_policy.monitoring_policy.arn
}

#  Criar o Perfil da Instância
resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.monitoring_role.name
}