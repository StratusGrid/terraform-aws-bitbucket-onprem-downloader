variable "apigw_logging_level" {
  description = "Can be OFF, INFO, or ERROR."
  type        = string
  default     = "OFF"
}

variable "apigw_metrics_enabled" {
  description = "Enable metrics for the prod stage of the API GW."
  type        = bool
  default     = false
}

variable "apigw_stage_name" {
  description = "Stage name for API GW"
  type        = string
  default     = "prod"
}

variable "current_account" {
  description = "The AWS account number of the caller."
  type        = string
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
  type        = string
}

variable "lambda_bitbucket_secret" {
  description = "The Bitbucket secret used to sign webhooks."
  type        = string
}

variable "lambda_bitbucket_server_url" {
  description = "URL for the 3rd party Bitbucket server."
  type        = string
}

variable "lambda_subnet_ids" {
  description = "List of subnets where the lambda will operate."
  type        = list(string)
}

variable "lambda_vpc_id" {
  description = "VPC to use when creating the SG for the Lambda"
  type        = string
}

variable "name" {
  type        = string
  default     = "onprem-git-downloader-module"
  description = "name to prepend to all resource names within module"
}

variable "s3_bucket_arn" {
  description = "S3 bucket where code artifacts will be stored. Used for IAM policy documents."
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket where code artifacts will be stored. Used for Lambda env vars."
  type        = string
}

variable "lambda_tracing_option" {
  description = "Lambda Tracing option whether to sample and trace a subset of incoming requests with AWS X-Ray."
  type        = string
  default     = "Active"
}

variable "kms_log_key_deletion_window" {
  description = "Duration (in day) of kms key created, default is 30"
  type        = number
}
