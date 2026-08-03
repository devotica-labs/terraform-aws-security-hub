output "hub_arn" {
  value = module.security_hub.hub_arn
}

output "enabled_standards_arns" {
  value = module.security_hub.enabled_standards_arns
}

output "finding_aggregator_arn" {
  value = module.security_hub.finding_aggregator_arn
}

output "findings_event_rule_arn" {
  value = module.security_hub.findings_event_rule_arn
}

output "findings_topic_arn" {
  value = aws_sns_topic.findings.arn
}
