# ─────────────────────────────────────────────────────────────
# ALB用Security Group 
# ─────────────────────────────────────────────────────────────
resource "aws_security_group" "alb_sg_primary" {
  name   = "alb-sg-primary"
  vpc_id = module.vpc_primary.vpc_id

  # インターネットの HTTP, HTTPSを許可
  ingress {
    description      = "Allow HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Allow HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # アウトバンドを全許可
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "alb_sg_secondary" {
  provider = aws.secondary
  name     = "alb-sg-secondary"
  vpc_id   = module.vpc_secondary.vpc_id

  # インターネットの HTTP, HTTPSを許可
  ingress {
    description      = "Allow HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Allow HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # アウトバンドを全許可
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


# ─────────────────────────────────────────────────────────────
# ALB の作成 (Primary, Secondary)
# Public Subnet に配置し、上記 EC2 を Targets として登録
# ─────────────────────────────────────────────────────────────
resource "aws_lb" "alb_primary" {
  name               = "alb-primary"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_primary.id]
  subnets            = module.vpc_primary.public_subnet_ids

  # 必要に応じてアクセスログの設定など適宜追加
  tags = {
    Name = "alb-primary"
  }
}

resource "aws_lb" "alb_secondary" {
  provider           = aws.secondary
  name               = "alb-secondary"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_secondary.id]
  subnets            = module.vpc_secondary.public_subnet_ids

  tags = {
    Name = "alb-secondary"
  }
}

# ターゲットグループ (EC2 へ forward)
resource "aws_lb_target_group" "tg_primary" {
  name        = "tg-primary"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc_primary.vpc_id
  target_type = "instance"
  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group" "tg_secondary" {
  provider    = aws.secondary
  name        = "tg-secondary"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc_secondary.vpc_id
  target_type = "instance"
  health_check {
    path = "/"
  }
}

# EC2 登録
resource "aws_lb_target_group_attachment" "tg_attach_primary" {
  target_group_arn = aws_lb_target_group.tg_primary.arn
  target_id        = aws_instance.web_primary.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg_attach_secondary" {
  provider         = aws.secondary
  target_group_arn = aws_lb_target_group.tg_secondary.arn
  target_id        = aws_instance.web_secondary.id
  port             = 80
}

# HTTP リスナー (ポート80)
# すべてのリクエストをHTTPSにリダイレクトする
resource "aws_lb_listener" "http_listener_primary" {
  load_balancer_arn = aws_lb.alb_primary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "http_listener_secondary" {
  provider          = aws.secondary
  load_balancer_arn = aws_lb.alb_secondary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS リスナー (ポート443)
# 証明書ARNとポリシーを指定し、ターゲットグループへ転送する
resource "aws_lb_listener" "https_listener_primary" {
  load_balancer_arn = aws_lb.alb_primary.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.acm_certificate_arn_primary
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_primary.arn
  }
}

resource "aws_lb_listener" "https_listener_secondary" {
  provider          = aws.secondary
  load_balancer_arn = aws_lb.alb_secondary.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.acm_certificate_arn_secondary
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_secondary.arn
  }
}
