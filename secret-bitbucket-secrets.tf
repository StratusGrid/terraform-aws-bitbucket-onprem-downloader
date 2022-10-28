# This secret will store sensitive values which must be retrieved by the downloader lambda.
# Specifically, the bitbucket access token and signing secret.
resource "aws_kms_key" "bitbucket_pat_and_signing_key" {
  description             = "KMS key used to encrypt bitbucket token and secret"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_log_key_deletion_window
}

resource "aws_secretsmanager_secret" "bitbucket_pat_and_signing_key" {
  name        = "${var.name}-bitbucket-secret"
  description = "Personal Access Token and Webhook Signing Key for Bitbucket."
  kms_key_id  = aws_kms_key.bitbucket_pat_and_signing_key.arn

  tags = merge(var.input_tags,
    {
      "Name" = "${var.name}-bitbucket-secret"
    }
  )
}

locals {
  bitbucket_secrets = jsonencode({
    "bitbucket_secret" : var.lambda_bitbucket_secret,
    "bitbucket_token" : var.lambda_bitbucket_access_token
  })
}

resource "aws_secretsmanager_secret_version" "bitbucket_pat_and_signing_key" {
  secret_id     = aws_secretsmanager_secret.bitbucket_pat_and_signing_key.id
  secret_string = local.bitbucket_secrets
}
