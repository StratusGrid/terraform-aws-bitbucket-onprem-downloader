<!-- BEGIN_TF_DOCS -->
# terraform-aws-bitbucket-onprem-downloader

GitHub: [StratusGrid/terraform-aws-bitbucket-onprem-downloader](https://github.com/StratusGrid/terraform-aws-bitbucket-onprem-downloader)

This module creates an API Gateway, Lambda, and supporting resources.
The API GW accepts an incoming webhook from a 3rd-party (on premise) Bitbucket server and triggers the Lambda which requests a ZIP archive of the repository which triggered the webhook, and uploads that ZIP to a provided S3 bucket.

<span style="color:red">NOTE:</span> The resulting archive will be named after the branch being retrieved, and any forward slashes will be replaced with hyphens.

### Pre-deployment Checklist:
Navigate into the "lambda" directory and build the requisite modules:
```shell
cd lambda
npm install
```

## Example usage of the module:
```hcl
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
```
---

## Resources

| Name | Type |
|------|------|
| [aws_api_gateway_deployment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_integration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_method.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method_settings.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_settings) | resource |
| [aws_api_gateway_resource.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_rest_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_cloudwatch_log_group.api_gw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.s3_bucket_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.secret_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.bitbucket_integration_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.aws_lambda_vpc_access_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.s3_bucket_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.secret_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_function.bitbucket_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.bitbucket_integration_api_gw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_secretsmanager_secret.bitbucket_pat_and_signing_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.bitbucket_pat_and_signing_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.lambda_function_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_apigw_logging_level"></a> [apigw\_logging\_level](#input\_apigw\_logging\_level) | Can be OFF, INFO, or ERROR. | `string` | `"OFF"` | no |
| <a name="input_apigw_metrics_enabled"></a> [apigw\_metrics\_enabled](#input\_apigw\_metrics\_enabled) | Enable metrics for the prod stage of the API GW. | `bool` | `false` | no |
| <a name="input_apigw_stage_name"></a> [apigw\_stage\_name](#input\_apigw\_stage\_name) | Stage name for API GW | `string` | `"prod"` | no |
| <a name="input_current_account"></a> [current\_account](#input\_current\_account) | The AWS account number of the caller. | `string` | n/a | yes |
| <a name="input_input_tags"></a> [input\_tags](#input\_input\_tags) | Map of tags to apply to resources | `map(string)` | <pre>{<br>  "Developer": "StratusGrid",<br>  "Provisioner": "Terraform"<br>}</pre> | no |
| <a name="input_lambda_bitbucket_access_token"></a> [lambda\_bitbucket\_access\_token](#input\_lambda\_bitbucket\_access\_token) | Personal Access Token used to authenticate to the Bitbucket server. | `string` | n/a | yes |
| <a name="input_lambda_bitbucket_secret"></a> [lambda\_bitbucket\_secret](#input\_lambda\_bitbucket\_secret) | The Bitbucket secret used to sign webhooks. | `string` | n/a | yes |
| <a name="input_lambda_bitbucket_server_url"></a> [lambda\_bitbucket\_server\_url](#input\_lambda\_bitbucket\_server\_url) | URL for the 3rd party Bitbucket server. | `string` | n/a | yes |
| <a name="input_lambda_subnet_ids"></a> [lambda\_subnet\_ids](#input\_lambda\_subnet\_ids) | List of subnets where the lambda will operate. | `list(string)` | n/a | yes |
| <a name="input_lambda_vpc_id"></a> [lambda\_vpc\_id](#input\_lambda\_vpc\_id) | VPC to use when creating the SG for the Lambda | `string` | n/a | yes |
| <a name="input_lambda_webproxy_host"></a> [lambda\_webproxy\_host](#input\_lambda\_webproxy\_host) | Hostname of your proxy server used by the Lambda function to access the Bitbucket server, such as myproxy.mydomain.com. If you don’t need a web proxy, leave it blank. | `string` | `""` | no |
| <a name="input_lambda_webproxy_port"></a> [lambda\_webproxy\_port](#input\_lambda\_webproxy\_port) | Port of your proxy server used by the Lambda function to access the Bitbucket server, such as 8080. If you don’t need a web proxy leave it blank. | `string` | `""` | no |
| <a name="input_name"></a> [name](#input\_name) | name to prepend to all resource names within module | `string` | `"onprem-git-downloader-module"` | no |
| <a name="input_s3_bucket_arn"></a> [s3\_bucket\_arn](#input\_s3\_bucket\_arn) | S3 bucket where code artifacts will be stored. Used for IAM policy documents. | `string` | n/a | yes |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | S3 bucket where code artifacts will be stored. Used for Lambda env vars. | `string` | n/a | yes |

## Outputs

No outputs.

---

<span style="color:red">Note:</span> Manual changes to the README will be overwritten when the documentation is updated. To update the documentation, run `terraform-docs -c .config/.terraform-docs.yml .`
<!-- END_TF_DOCS -->