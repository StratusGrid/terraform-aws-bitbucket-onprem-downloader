# This secret will store sensitive values which must be retrieved by the downloader lambda.
# Specifically, the bitbucket access token and signing secret.

#tfsec:ignore:aws-ssm-secret-use-customer-key -- Ignores warning on usage of AWS managed key instead of a specific/custom one.
resource "aws_secretsmanager_secret" "bitbucket_pat_and_signing_key" {
  name        = "${var.name}-bitbucket-secret"
  description = "Personal Access Token and Webhook Signing Key for Bitbucket."

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

# tflint-ignore: all
data "aws_secretsmanager_secret_version" "bitbucket_pat_and_signing_key" {
  depends_on = [aws_secretsmanager_secret_version.bitbucket_pat_and_signing_key]
  secret_id  = aws_secretsmanager_secret.bitbucket_pat_and_signing_key.id
}