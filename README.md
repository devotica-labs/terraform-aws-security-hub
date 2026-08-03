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
<!-- END_TF_DOCS -->

## License

See [LICENSE](./LICENSE).
