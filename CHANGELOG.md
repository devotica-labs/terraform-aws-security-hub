# Changelog

## [Unreleased]

### Features

- Enable Security Hub for the account/region (`manage_account`, opt-out
  for AWS Organizations delegated-admin scenarios)
- Subscribe to security standards by short key: `aws-foundational-security-best-practices`,
  `cis-aws-foundations`, `pci-dss`, `nist-800-53`
- Optional cross-region finding aggregation (`enable_finding_aggregator`,
  `region_linking_mode`, `linked_regions`)
- Optional findings notification via EventBridge to an existing SNS topic,
  filtered by minimum severity (`notification_sns_topic_arn`,
  `notification_minimum_severity`)
