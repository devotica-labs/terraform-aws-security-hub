locals {
  common_tags = merge(
    { ManagedBy = "terraform", Module = "terraform-aws-security-hub" },
    var.tags
  )

  # Short key -> full standards ARN, region-qualified. Versions pinned to
  # what's current as of this module's authoring; check the AWS Security
  # Hub console's "Security standards" page for newer versions before
  # bumping.
  standards_map = {
    aws-foundational-security-best-practices = "arn:aws:securityhub:${data.aws_region.current.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
    cis-aws-foundations                      = "arn:aws:securityhub:${data.aws_region.current.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
    pci-dss                                  = "arn:aws:securityhub:${data.aws_region.current.region}::standards/pci-dss/v/3.2.1"
    nist-800-53                              = "arn:aws:securityhub:${data.aws_region.current.region}::standards/nist-800-53/v/5.0.0"
  }

  standards_arns = [for s in var.standards : local.standards_map[s]]

  need_notifications = var.notification_sns_topic_arn != ""

  # Ordered low -> high; used to compute which labels satisfy "at or above
  # the configured minimum" for the EventBridge event pattern.
  severity_order = ["INFORMATIONAL", "LOW", "MEDIUM", "HIGH", "CRITICAL"]
  severities_included = slice(
    local.severity_order,
    index(local.severity_order, var.notification_minimum_severity),
    length(local.severity_order)
  )
}
