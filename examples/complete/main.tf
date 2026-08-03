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

# ---------------------------------------------------------------------------
# A destination topic for findings notifications, created inline here for
# a self-contained example. In a real environment this would typically be
# the sibling terraform-aws-sns module instead — see the policy statement
# below for exactly what that module's policy_principals needs to grant.
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "findings" {
  name = "dvtca-sandbox-securityhub-findings"
}

data "aws_iam_policy_document" "allow_eventbridge_publish" {
  statement {
    sid     = "AllowEventBridgePublish"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.findings.arn]
  }
}

resource "aws_sns_topic_policy" "findings" {
  arn    = aws_sns_topic.findings.arn
  policy = data.aws_iam_policy_document.allow_eventbridge_publish.json
}

# Uses local path during development.
# Change to Registry source after first release:
#   source  = "devotica-labs/security-hub/aws"
#   version = "~> 0.1"

module "security_hub" {
  source = "../.."

  name = "dvtca-sandbox"

  # All four supported standards for a fintech-grade baseline.
  standards = [
    "aws-foundational-security-best-practices",
    "cis-aws-foundations",
    "pci-dss",
    "nist-800-53",
  ]

  # Single-region deployment here, but demonstrates the aggregator wiring
  # for when a real multi-region footprint needs one pane of glass.
  enable_finding_aggregator = true
  region_linking_mode       = "ALL_REGIONS"

  # Route HIGH and CRITICAL findings to the topic above.
  notification_sns_topic_arn    = aws_sns_topic.findings.arn
  notification_minimum_severity = "HIGH"

  tags = {
    Environment = "sandbox"
    Project     = "terraform-aws-security-hub"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM-OSS"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-security-hub"
  }
}
