variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "bedrock-chatbot"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for remote Terraform state"
  type        = string
}

variable "github_repo" {
  description = "owner/name of the GitHub repo that CI runs from"
  type        = string
  default     = "vakulj28/BedrockChatbot"
}

variable "github_actor" {
  description = "GitHub user allowed to trigger workflows that assume the CI roles"
  type        = string
  default     = "vakulj28"
}

variable "github_environment" {
  description = "GitHub Environment the deploy role will trust (created later)"
  type        = string
  default     = "bedrock-chatbot-prod"
}

variable "budget_limit_usd" {
  description = "Monthly budget ceiling in USD"
  type        = string
  default     = "5"
}

variable "budget_notify_email" {
  description = "Email that receives budget alerts"
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda Web Function"
  type        = string
  default     = "bedrock-chatbot"
}

variable "model_id" {
  description = "Bedrock inference profile ID the app invokes"
  type        = string
  default     = "eu.amazon.nova-lite-v1:0"
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the Web Function"
  type        = number
  default     = 14
}

variable "web_function_domain" {
  description = "The prod endpoint domain of the manually-created Web Function"
  type        = string
}