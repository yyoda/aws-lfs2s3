variable "name" {
  default = "yyoda"
}

variable "profile" {
  default = "xxxx"
}

variable "region" {
  default = "ap-northeast-1"
}

variable "gitlfs_s3_bucket" {
  default = "yyoda-ap-northeast-1-gitlfs"
}

variable "gitlfs_username" {
  default = "yyoda"
}

variable "gitlfs_password" {
  default = "password"
}

variable "gitlfs_allow_ips" {
  default = [
    "xxx.xxx.xxx.xxx/32"
  ]
}
