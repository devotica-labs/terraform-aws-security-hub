output "hub_arn" {
  description = "ARN of the Security Hub resource for this account/region, or null when manage_account = false."
  value       = try(aws_securityhub_account.this[0].id, null)
}

output "enabled_standards_arns" {
  description = "ARNs of the security standards this module subscribed the account to."
  value       = local.standards_arns
}

output "finding_aggregator_arn" {
  description = "ARN of the cross-region finding aggregator, or null when enable_finding_aggregator = false."
  value       = try(aws_securityhub_finding_aggregator.this[0].arn, null)
}

output "findings_event_rule_arn" {
  description = "ARN of the EventBridge rule routing findings to SNS, or null when notification_sns_topic_arn is empty."
  value       = try(aws_cloudwatch_event_rule.findings[0].arn, null)
}
