# ─────────────────────────────────────────────────────────────
# EC2 用の IAM ロール・ポリシー (Session Manager 用)
# ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2_ssm_role" {
  name               = "ec2_ssm_role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ─────────────────────────────────────────────────────────────
# Security Group (SSH を使わず Session Manager 接続想定なのでインバウンドは最小限)
# ─────────────────────────────────────────────────────────────
resource "aws_security_group" "web_sg_primary" {
  name   = "web-sg-primary"
  vpc_id = module.vpc_primary.vpc_id

  # ALB からの 80 番受け取り (同一 VPC 内通信なら SG 同士のルールでもOK)
  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg_primary.id]
  }

  # Session Manager 用に通信を制限したい場合は SSM 関連エンドポイントの SG と紐付けるなど検討
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "web_sg_secondary" {
  provider = aws.secondary
  name     = "web-sg-secondary"
  vpc_id   = module.vpc_secondary.vpc_id

  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg_secondary.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# ─────────────────────────────────────────────────────────────
# EC2 インスタンス定義 (Private Subnet に配置)
# ALB 経由で 80 番アクセス、Session Manager 経由で操作想定
# ─────────────────────────────────────────────────────────────
# AMI の指定。Amazon Linux 2023。リージョンごとにAMIのIDが違う
data "aws_ami" "amazon_linux_primary" {
  most_recent = true
  owners      = ["137112412989"] # AmazonのAMI所有者ID

  filter {
    name = "name"
    # Amazon Linux 2023 AMIの名前パターン。minimumを除外する
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "amazon_linux_secondary" {
  provider    = aws.secondary
  most_recent = true
  owners      = ["137112412989"] # AmazonのAMI所有者ID

  filter {
    name = "name"
    # Amazon Linux 2023 AMIの名前パターン。minimumを除外する
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web_primary" {
  ami                  = data.aws_ami.amazon_linux_primary.image_id
  instance_type        = "t3.small"
  subnet_id            = element(module.vpc_primary.private_subnet_ids, 0)
  security_groups      = [aws_security_group.web_sg_primary.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y httpd
    systemctl enable httpd
    systemctl start httpd

    echo "<h1>Hello from PRIMARY Region: ap-notheast-1</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "web-primary"
  }
}

resource "aws_instance" "web_secondary" {
  provider             = aws.secondary
  ami                  = data.aws_ami.amazon_linux_secondary.image_id
  instance_type        = "t3.small"
  subnet_id            = element(module.vpc_secondary.private_subnet_ids, 0)
  security_groups      = [aws_security_group.web_sg_secondary.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y httpd
    systemctl enable httpd
    systemctl start httpd

    echo "<h1>Hello from SECONDARY Region: us-east-1</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "web-secondary"
  }
}

# ─────────────────────────────────────────────────────────────
# IAM インスタンスプロファイル (EC2 → SSM Role 紐づけ)
# ─────────────────────────────────────────────────────────────
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
