# Lambda which is triggered by API GW. Reaches out to Bitbucket server, requests ZIP archive of repository, and pushes that archive to S3.

# Data object to provide lambda archive for upload to AWS
data "archive_file" "function_code" {
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/lambda.zip"
  type        = "zip"
  excludes    = ["${path.module}/lambda/lambda.zip"]
}

resource "aws_lambda_function" "bitbucket_integration" {
  function_name    = "${var.name}-bitbucket-integration"
  handler          = "index.handler"
  layers           = []
  role             = aws_iam_role.bitbucket_integration_role.arn
  runtime          = "nodejs14.x"
  timeout          = 30
  filename         = data.archive_file.function_code.output_path
  source_code_hash = filebase64sha256(data.archive_file.function_code.output_path)

  environment {
    variables = {
      "BITBUCKET_SECRET_NAME" = aws_secretsmanager_secret.bitbucket_pat_and_signing_key.id
      "BITBUCKET_SERVER_URL"  = var.lambda_bitbucket_server_url
      "S3BUCKET"              = var.s3_bucket_name
      "WEBPROXY_HOST"         = ""
      "WEBPROXY_PORT"         = ""
    }
  }
  kms_key_arn = aws_kms_key.this.arn
  timeouts {}

  tracing_config {
    mode = var.lambda_tracing_option
  }

  vpc_config {
    security_group_ids = [
      aws_security_group.lambda_function_sg.id
    ]
    subnet_ids = var.lambda_subnet_ids
  }

  tags = merge(var.input_tags, {
    "Name" = "${var.name}-bitbucket-integration"
  })
}

resource "aws_iam_role" "bitbucket_integration_role" {
  name               = "${var.name}-bitbucket-integration-lambda-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "BitBucketIntegrationRole"
    }
  ]
}
EOF
  tags = merge(var.input_tags, {
    "Name" = "${var.name}-bitbucket-integration-lambda-role"
  })
}

resource "aws_iam_policy" "s3_bucket_access" {
  description = "Access to S3 bucket used for code and pipeline artifacts"
  name        = "${var.name}-bitbucket-integration-s3-access"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Resource": [
        "${var.s3_bucket_arn}",
        "${var.s3_bucket_arn}/*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "kms:decrypt"
      ],
      "Resource": [
        "${aws_kms_key.this.arn}"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF
  tags = merge(var.input_tags, {
    "Name" = "${var.name}-bitbucket-integration-s3-access"
  })
}

resource "aws_iam_policy" "secret_access" {
  description = "Access to Bitbucket Secret"
  name        = "${var.name}-bitbucket-integration-sm-access"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "${aws_secretsmanager_secret.bitbucket_pat_and_signing_key.arn}"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF
  tags = merge(var.input_tags, {
    "Name" = "${var.name}-bitbucket-integration-sm-access"
  })
}

resource "aws_iam_role_policy_attachment" "s3_bucket_access" {
  policy_arn = aws_iam_policy.s3_bucket_access.arn
  role       = aws_iam_role.bitbucket_integration_role.name
}

resource "aws_iam_role_policy_attachment" "secret_access" {
  policy_arn = aws_iam_policy.secret_access.arn
  role       = aws_iam_role.bitbucket_integration_role.name
}

resource "aws_iam_role_policy_attachment" "aws_lambda_vpc_access_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.bitbucket_integration_role.name
}

resource "aws_lambda_permission" "bitbucket_integration_api_gw" {
  statement_id  = "AllowAPIGWBitBucketIntegrationInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bitbucket_integration.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*/*"
}

# TODO: The account number in the policy below needs to be updated once a PRD account has been defined.
resource "aws_kms_key" "this" {
  description             = "CMK used by the Lambda Function to encrypt the environment variables."
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_log_key_deletion_window

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Id": "root",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.current_account}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        }
    ]
}
EOF
  tags   = var.input_tags
}

resource "aws_kms_alias" "this" {
  target_key_id = aws_kms_key.this.id
  name          = "alias/${var.name}-lambda-key"
}

resource "aws_security_group" "lambda_function_sg" {
  name        = "${var.name}-bitbucket-integration-lambda-sg"
  description = "Security group to allow outbound traffic from the lambda function."
  #tfsec:ignore:aws-ec2-no-public-egress-sgr -- Ignore warning on egress to multiple public internet addresses
  egress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    description      = "Allow all outbound traffic to all addresses."
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }
  vpc_id = var.lambda_vpc_id
  tags = merge(var.input_tags, {
    "Name" = "${var.name}-bitbucket-integration-lambda-sg"
  })
  lifecycle {
    create_before_destroy = true
  }
}
