# Changelog

## [0.1.1](https://github.com/devotica-labs/terraform-aws-security-hub/compare/v0.1.0...v0.1.1) (2026-08-09)


### Bug Fixes

* aws_securityhub_finding_aggregator has no unlinked_regions argument ([6a1a608](https://github.com/devotica-labs/terraform-aws-security-hub/commit/6a1a608f3995cfc1b9334fb95c5704b7426924b5))

## 0.1.0 (2026-08-03)


### Features

* initial Security Hub module — account enablement, standards subscriptions, cross-region aggregation, findings notifications ([c5c4f19](https://github.com/devotica-labs/terraform-aws-security-hub/commit/c5c4f19b90e3283534cd6c92b95620333017abf4))

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
