# bitbucket-onprem-git-downloader

This module creates an API Gateway, Lambda, and supporting resources.
The API GW accepts an incoming webhook from a 3rd-party (on premise) Bitbucket server and triggers the Lambda which requests a ZIP archive of the repository which triggered the webhook, and uploads that ZIP to a provided S3 bucket.
Note that the resulting archive will be named after the branch being retrieved, and any forward slashes will be replaced with hyphens.

### Pre-deployment Checklist:
Navigate into the "lambda" directory and build the requisite modules:
```shell
cd lambda
npm install
```

### Example:
```
module "onprem_bitbucket_git_downloader" {
  source                        = "../.."
  name                          = "${var.name_prefix}-bitbucket-git-downloader"
  apigw_logging_level           = "ERROR"
  apigw_metrics_enabled         = true
  apigw_stage_name              = "prod"
  current_account               = data.aws_caller_identity.current.account_id
  lambda_bitbucket_access_token = data.aws_secretsmanager_secret_version.bitbucket_token.secret_string
  lambda_bitbucket_secret       = data.aws_secretsmanager_secret_version.bitbucket_secret.secret_string
  lambda_bitbucket_server_url   = "https://bitbucket.onpremisedomain.net"
  lambda_subnet_ids             = data.aws_subnet_ids.private_subnets.ids
  lambda_vpc_id                 = data.aws_vpc.my_vpc.id
  s3_bucket_arn                 = aws_s3_bucket.s3_bucket.arn
  s3_bucket_name                = aws_s3_bucket.s3_bucket.bucket
}

data "aws_iam_policy_document" "s3_bucket_access" {
  statement {
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.s3_bucket.arn,
    ]
  }

  statement {
    actions = [
      "s3:List*",
      "s3:Get*",
      "s3:Put*",
    ]

    resources = [
      "${aws_s3_bucket.s3_bucket.arn}/*",
    ]
  }
}

# This bucket is used to store config files, binaries, artifacts etc. 
# for the service build and deployment operations.

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${var.name_prefix}-resources${local.name_suffix}"

  versioning {
    enabled = true
  }

  lifecycle {
    #    prevent_destroy = true
    prevent_destroy = false
  }

  lifecycle_rule {
    id      = "artifacts"
    enabled = true

    abort_incomplete_multipart_upload_days = 0

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days                         = 90
      expired_object_delete_marker = false
    }
  }

  logging {
    target_bucket = data.aws_s3_bucket.logging.id
    target_prefix = "s3/logs/${var.name_prefix}-resources${local.name_suffix}/"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
      bucket_key_enabled = false
    }
  }

  tags = merge(local.common_tags, {})
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions = [
      "s3:*",
    ]
    condition {
      test = "Bool"
      values = [
        "false",
      ]
      variable = "aws:SecureTransport"
    }
    effect = "Deny"
    principals {
      identifiers = [
        "*",
      ]
      type = "AWS"
    }
    resources = [
      aws_s3_bucket.s3_bucket.arn,
      "${aws_s3_bucket.s3_bucket.arn}/*",
    ]
    sid = "DenyUnsecuredTransport"
  }
}

resource "aws_s3_bucket_policy" "s3_bucket_policy_mapping" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

# These secrets provide critical authentication and encryption for the lambda
# which accesses the on-premise Bitbucket server

# Secret to hold Bitbucket personal access token (PAT)
resource "aws_secretsmanager_secret" "bitbucket_token" {
  name = "${var.name_prefix}-bitbucket-token${local.name_suffix}"
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name_prefix}-bitbucket-token${local.name_suffix}"
    },
  )
}

data "aws_secretsmanager_secret_version" "bitbucket_token" {
  secret_id = aws_secretsmanager_secret.bitbucket_token.id
}

# Secret to hold Bitbucket webhook signing secret
resource "aws_secretsmanager_secret" "bitbucket_secret" {
  name = "${var.name_prefix}-bitbucket-secret${local.name_suffix}"
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name_prefix}-bitbucket-secret${local.name_suffix}"
    },
  )
}

data "aws_secretsmanager_secret_version" "bitbucket_secret" {
  secret_id = aws_secretsmanager_secret.bitbucket_secret.id
}

```
