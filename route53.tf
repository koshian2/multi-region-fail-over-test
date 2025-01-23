# ─────────────────────────────────────────────────────────────
# Route53 のHosted Zone は既存を仮定 (あるいは新規作成でもOK)
# data で取得したり、resource で作成したりする
# ─────────────────────────────────────────────────────────────
data "aws_route53_zone" "main" {
  # 既存のドメインを使う例
  name         = var.hosted_zone_name
  private_zone = false
}

# ヘルスチェック (フェイルオーバーで使う例)
resource "aws_route53_health_check" "primary" {
  # ALB Primary に対する HTTP ヘルスチェック
  type              = "HTTP"
  resource_path     = "/"
  fqdn              = aws_lb.alb_primary.dns_name
  port              = 80
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "secondary" {
  # ALB Secondary に対する HTTP ヘルスチェック
  type              = "HTTP"
  resource_path     = "/"
  fqdn              = aws_lb.alb_secondary.dns_name
  port              = 80
  failure_threshold = 3
  request_interval  = 30
}

# フェイルオーバー用 レコード: Primary
resource "aws_route53_record" "failover_primary" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = var.record_name # 例: "www"
  type            = "A"
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_lb.alb_primary.dns_name
    zone_id                = aws_lb.alb_primary.zone_id
    evaluate_target_health = true
  }
}

# フェイルオーバー用 レコード: Secondary
resource "aws_route53_record" "failover_secondary" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = var.record_name
  type            = "A"
  set_identifier  = "secondary"
  health_check_id = aws_route53_health_check.secondary.id

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = aws_lb.alb_secondary.dns_name
    zone_id                = aws_lb.alb_secondary.zone_id
    evaluate_target_health = true
  }
}