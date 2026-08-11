# terraform-aws-security-hub

Enables AWS Security Hub for an account/region, subscribes it to security
standards (CIS, AWS Foundational Security Best Practices, PCI-DSS,
NIST 800-53), optionally aggregates findings across regions, and
optionally routes findings above a severity threshold to an existing SNS
topic via EventBridge.

Part of the [Devotica Terraform module catalog](https://registry.terraform.io/modules/devotica-labs).

[![CI](https://github.com/devotica-labs/terraform-aws-security-hub/actions/workflows/ci.yml/badge.svg)](https://github.com/devotica-labs/terraform-aws-security-hub/actions/workflows/ci.yml)
[![Architecture](https://github.com/devotica-labs/terraform-aws-security-hub/actions/workflows/architecture-diagram.yml/badge.svg)](https://github.com/devotica-labs/terraform-aws-security-hub/actions/workflows/architecture-diagram.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

## Architecture

<!-- BEGIN_ARCH -->
<!-- END_ARCH -->

## Usage

```hcl
module "security_hub" {
  source  = "devotica-labs/security-hub/aws"
  version = "~> 0.1"

  name = "prod"

  standards = [
    "aws-foundational-security-best-practices",
    "cis-aws-foundations",
    "pci-dss",
  ]

  notification_sns_topic_arn    = module.sns.topic_arn
  notification_minimum_severity = "HIGH"

  tags = {
    Environment = "prod"
    Project     = "security"
    Owner       = "security-team@example.com"
    CostCenter  = "SEC-001"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/example/security-infra"
  }
}
```

See `examples/basic` for the minimal case (just enablement + the two
default standards) and `examples/complete` for the full feature set:
all four standards, cross-region finding aggregation, and findings
notifications.

## Design notes

- **`manage_account` (default `true`) exists because Security Hub is a
  per-account singleton**, unlike the resources most of this catalog
  wraps. If Security Hub is already enabled centrally via AWS
  Organizations delegated administration, set `manage_account = false`
  in member accounts so this module only manages standards subscriptions
  and notifications against the Hub the org admin already enabled —
  otherwise `aws_securityhub_account` errors on an already-enabled
  account.
- **This module does not manage the destination SNS topic's policy.**
  Two Terraform resources independently calling `aws_sns_topic_policy` on
  the same topic ARN fight over full ownership of the policy document,
  causing perpetual plan diffs. Grant `events.amazonaws.com` publish
  access on the target topic yourself — if using the sibling
  `terraform-aws-sns` module, that looks like:

  ```hcl
  policy_principals = [
    {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
      actions     = ["SNS:Publish"]
    }
  ]
  ```

- **`enable_default_standards = false` is hardcoded.** Security Hub's
  own auto-enrollment (CIS + AWS Foundational on account creation) is
  disabled so `var.standards` is the single source of truth for which
  standards are active — avoids a standard being subscribed twice
  through two different mechanisms.
- **Only one finding aggregator can exist per account.** If you call
  this module in more than one region, set `enable_finding_aggregator =
  true` in exactly one of them.
- **Standards ARNs are version-pinned** in `locals.tf` to what was
  current at authoring time. Check the Security Hub console's "Security
  standards" page before assuming a newer version is automatically
  picked up — bumping the version string is a manual, deliberate update.

<!-- BEGIN_TF_DOCS -->


## Usage

### Basic

```hcl
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
```

### Complete

```hcl
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
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.44 |
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.44 |
## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.findings](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.findings_to_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_securityhub_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_account) | resource |
| [aws_securityhub_finding_aggregator.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_finding_aggregator) | resource |
| [aws_securityhub_standards_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_standards_subscription) | resource |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Logical name for this deployment. Security Hub itself is an account+region singleton (there's only ever one per account/region), so this only prefixes the child resources this module creates — the findings EventBridge rule, primarily. | `string` | n/a | yes |
| <a name="input_auto_enable_controls"></a> [auto\_enable\_controls](#input\_auto\_enable\_controls) | Automatically enable new controls that AWS adds to already-enabled standards, without requiring a re-apply. Ignored when manage\_account = false. | `bool` | `true` | no |
| <a name="input_control_finding_generator"></a> [control\_finding\_generator](#input\_control\_finding\_generator) | Whether findings are generated per security control (STANDARD\_CONTROL, deduplicated across standards — AWS's current recommendation) or per standard-check (SECURITY\_CONTROL, one finding per standard even for the same underlying control). Ignored when manage\_account = false. | `string` | `"SECURITY_CONTROL"` | no |
| <a name="input_enable_finding_aggregator"></a> [enable\_finding\_aggregator](#input\_enable\_finding\_aggregator) | Aggregate findings from other regions into this one (a single pane of glass across a multi-region footprint). Only one aggregator can exist per account — creating this in more than one region's module call will conflict. | `bool` | `false` | no |
| <a name="input_linked_regions"></a> [linked\_regions](#input\_linked\_regions) | Region names to include (SPECIFIED\_REGIONS) or exclude (ALL\_REGIONS\_EXCEPT\_SPECIFIED). Ignored for ALL\_REGIONS. | `list(string)` | `[]` | no |
| <a name="input_manage_account"></a> [manage\_account](#input\_manage\_account) | Create the aws\_securityhub\_account resource (enables Security Hub in this account/region). Set to false when Security Hub is centrally enabled via AWS Organizations delegated administration and this module should only manage standards subscriptions / notifications against the existing Hub. | `bool` | `true` | no |
| <a name="input_notification_minimum_severity"></a> [notification\_minimum\_severity](#input\_notification\_minimum\_severity) | Minimum finding severity that triggers a notification: INFORMATIONAL, LOW, MEDIUM, HIGH, or CRITICAL. Ignored when notification\_sns\_topic\_arn is empty. | `string` | `"HIGH"` | no |
| <a name="input_notification_sns_topic_arn"></a> [notification\_sns\_topic\_arn](#input\_notification\_sns\_topic\_arn) | ARN of an existing SNS topic to receive findings at or above notification\_minimum\_severity. Leave empty (default) to skip creating the EventBridge rule entirely. The topic's own policy must separately grant events.amazonaws.com permission to publish — this module does not manage that policy. | `string` | `""` | no |
| <a name="input_region_linking_mode"></a> [region\_linking\_mode](#input\_region\_linking\_mode) | Which regions feed the aggregator: ALL\_REGIONS, ALL\_REGIONS\_EXCEPT\_SPECIFIED, or SPECIFIED\_REGIONS. Ignored when enable\_finding\_aggregator = false. | `string` | `"ALL_REGIONS"` | no |
| <a name="input_standards"></a> [standards](#input\_standards) | Security standards to subscribe to, by short key: "aws-foundational-security-best-practices", "cis-aws-foundations", "pci-dss", "nist-800-53". Fintech-safe default enables the two most broadly required frameworks. | `list(string)` | <pre>[<br/>  "aws-foundational-security-best-practices",<br/>  "cis-aws-foundations"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged onto every taggable resource (the EventBridge rule; Security Hub's own resources don't support tagging as of this module's provider pin). | `map(string)` | `{}` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_enabled_standards_arns"></a> [enabled\_standards\_arns](#output\_enabled\_standards\_arns) | ARNs of the security standards this module subscribed the account to. |
| <a name="output_finding_aggregator_arn"></a> [finding\_aggregator\_arn](#output\_finding\_aggregator\_arn) | ARN of the cross-region finding aggregator, or null when enable\_finding\_aggregator = false. |
| <a name="output_findings_event_rule_arn"></a> [findings\_event\_rule\_arn](#output\_findings\_event\_rule\_arn) | ARN of the EventBridge rule routing findings to SNS, or null when notification\_sns\_topic\_arn is empty. |
| <a name="output_hub_arn"></a> [hub\_arn](#output\_hub\_arn) | ARN of the Security Hub resource for this account/region, or null when manage\_account = false. |
<!-- END_TF_DOCS -->

## License

See [LICENSE](./LICENSE).
