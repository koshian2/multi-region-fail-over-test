provider "aws" {
  region  = "ap-northeast-1"
  profile = "<your-profile-name>"
}

provider "aws" {
  alias   = "secondary"
  region  = "us-east-1"
  profile = "<your-profile-name>"
}

terraform {
  backend "local" {
    path = ".cache/terraform.tfstate"
  }
}

# --------------------------------------------------------------------------------
# ■ variables.tf
# --------------------------------------------------------------------------------
variable "primary_vpc_name" {
  type    = string
  default = "multi-region-vpc-primary"
}

variable "secondary_vpc_name" {
  type    = string
  default = "multi-region-vpc-secondary"
}

variable "primary_vpc_cidr_block" {
  type    = string
  default = "172.19.0.0/20"
}

variable "secondary_vpc_cidr_block" {
  type    = string
  default = "172.20.0.0/20"
}

# それぞれのリージョンに合わせた AZ リストを指定
variable "primary_azs" {
  type    = list(string)
  default = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "secondary_azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1c", "us-east-1d"]
}

# Route53 ドメイン関係
variable "hosted_zone_name" {
  type        = string
  description = "既存の Route53 Hosted Zone 名 (ex: example.com.)"
}

variable "record_name" {
  type        = string
  description = "レコードのホスト部 (ex: www)"
  default     = "www"
}

# ACM 証明書 ARN (*.example.comのようにワイルドカードつけてリクエストしておく)
variable "acm_certificate_arn_primary" {
  type        = string
  description = "既に登録済みの ACM 証明書 ARN（プライマリリージョン）"
}

variable "acm_certificate_arn_secondary" {
  type        = string
  description = "既に登録済みの ACM 証明書 ARN（セカンダリリージョン）"
}