# ---------------------------------------------------------------------------
# Provider block — CI-friendly skip flags + non-AWS-shaped placeholder creds.
# ---------------------------------------------------------------------------
provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "not-a-real-aws-key"
  secret_key                  = "not-a-real-aws-secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Uses local path during development.
# Change to Registry source after first release:
#   source  = "devotica-labs/security-hub/aws"
#   version = "~> 0.1"

module "security_hub" {
  source = "../.."

  # Enables Security Hub with the two default standards
  # (aws-foundational-security-best-practices, cis-aws-foundations) and no
  # notification wiring — the simplest possible baseline.
  name = "dvtca-sandbox"

  tags = {
    Environment = "sandbox"
    Project     = "terraform-aws-security-hub"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM-OSS"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-security-hub"
  }
}
