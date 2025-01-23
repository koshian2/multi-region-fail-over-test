variable "vpc_name" {
  type        = string
  description = "Name of VPC"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block of VPC"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}
