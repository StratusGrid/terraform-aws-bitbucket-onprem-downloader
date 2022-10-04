resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.name}-bitbucket-integration-api-gw"
  description = "API used by the AWS CodePipeline integration with the Bitbucket Server."
  tags = merge(var.input_tags, {
    "Name" = "${var.name}-bitbucket-integration-api-gw"
  })
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.this.id,
      aws_api_gateway_method.this.id,
      aws_api_gateway_integration.this.id,
      aws_api_gateway_integration.this.uri
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_resource" "this" {
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "webhook"
  rest_api_id = aws_api_gateway_rest_api.this.id
}

#tfsec:ignore:aws-api-gateway-no-public-access -- Ignores on Authorization is not enabled
resource "aws_api_gateway_method" "this" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
}

resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.apigw_stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = var.apigw_metrics_enabled == true ? true : false
    logging_level   = var.apigw_logging_level
  }
}

resource "aws_api_gateway_integration" "this" {
  cache_key_parameters    = []
  cache_namespace         = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.this.http_method
  integration_http_method = aws_api_gateway_method.this.http_method
  passthrough_behavior    = "WHEN_NO_MATCH"
  request_parameters      = {}
  request_templates       = {}
  resource_id             = aws_api_gateway_resource.this.id
  rest_api_id             = aws_api_gateway_rest_api.this.id
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.bitbucket_integration.invoke_arn
}

#tfsec:ignore:aws-api-gateway-enable-access-logging -- Ignores warning on Access logging is not configured tfsec:ignore:aws-api-gateway-enable-tracing
resource "aws_api_gateway_stage" "this" {
  depends_on            = [aws_cloudwatch_log_group.api_gw]
  cache_cluster_enabled = false
  deployment_id         = aws_api_gateway_deployment.this.id
  rest_api_id           = aws_api_gateway_rest_api.this.id
  stage_name            = var.apigw_stage_name
  xray_tracing_enabled  = false
  tags = merge(var.input_tags, {
    "Name" = var.apigw_stage_name
  })
}

#tfsec:ignore:aws-cloudwatch-log-group-customer-key -- Ignores warning on Log group is not encrypted.
resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.this.id}/${var.apigw_stage_name}"
  retention_in_days = 7
  tags = merge(var.input_tags, {
    "Name" = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.this.id}/${var.apigw_stage_name}"
  })
}