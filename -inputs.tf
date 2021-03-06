variable "apigw_logging_level" {
  description = "Can be OFF, INFO, or ERROR."
  type = string
  default = "OFF"
}

variable "apigw_metrics_enabled" {
  description = "Enable metrics for the prod stage of the API GW."
  type = bool
  default = false
}

variable "apigw_stage_name" {
  description = "Stage name for API GW"
  type = string
  default = "prod"
}

variable "current_account" {
  description = "The AWS account number of the caller."
  type = string
}

variable "input_tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default = {
    Developer   = "StratusGrid"
    Provisioner = "Terraform"
  }
}

variable "lambda_bitbucket_access_token" {
  description = "Personal Access Token used to authenticate to the Bitbucket server."
  type = string
}

variable "lambda_bitbucket_secret" {
  description = "The Bitbucket secret used to sign webhooks."
  type = string
}

variable "lambda_bitbucket_server_url" {
  description = "URL for the 3rd party Bitbucket server."
  type = string
}

variable "lambda_subnet_ids" {
  description = "List of subnets where the lambda will operate."
  type = list(string)
}

variable "lambda_vpc_id" {
  description = "VPC to use when creating the SG for the Lambda"
  type = string
}

variable "lambda_webproxy_host" {
  description = "Hostname of your proxy server used by the Lambda function to access the Bitbucket server, such as myproxy.mydomain.com. If you don’t need a web proxy, leave it blank."
  type = string
  default = ""
}

variable "lambda_webproxy_port" {
  description = "Port of your proxy server used by the Lambda function to access the Bitbucket server, such as 8080. If you don’t need a web proxy leave it blank."
  type = string
  default = ""
}

variable "name" {
  type        = string
  default     = "onprem-git-downloader-module"
  description = "name to prepend to all resource names within module"
}

variable "s3_bucket_arn" {
  description = "S3 bucket where code artifacts will be stored. Used for IAM policy documents."
  type = string
}

variable "s3_bucket_name" {
  description = "S3 bucket where code artifacts will be stored. Used for Lambda env vars."
  type = string
}
