terraform {
  backend "s3" {
    bucket       = "bedrock-chatbot-tfstate"
    key          = "bedrock-chatbot/terraform.tfstate"
    region       = "eu-west-1"
    profile      = "chatbot"
    encrypt      = true
    use_lockfile = true
  }
}