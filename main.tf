# ---------------------------------------------------------------------------
# Security Hub account enablement — skipped when manage_account = false
# (Organizations-delegated-admin scenario; see variables.tf).
# ---------------------------------------------------------------------------

resource "aws_securityhub_account" "this" {
  count = var.manage_account ? 1 : 0

  auto_enable_controls      = var.auto_enable_controls
  control_finding_generator = var.control_finding_generator
  enable_default_standards  = false # standards are managed explicitly below
}

# ---------------------------------------------------------------------------
# Standards subscriptions
# ---------------------------------------------------------------------------

resource "aws_securityhub_standards_subscription" "this" {
  for_each = toset(local.standards_arns)

  standards_arn = each.value

  depends_on = [aws_securityhub_account.this]
}

# ---------------------------------------------------------------------------
# Cross-region finding aggregation
# ---------------------------------------------------------------------------

resource "aws_securityhub_finding_aggregator" "this" {
  count = var.enable_finding_aggregator ? 1 : 0

  linking_mode = var.region_linking_mode

  # The AWS provider has a single specified_regions argument reused for both
  # "regions to include" (SPECIFIED_REGIONS) and "regions to exclude"
  # (ALL_REGIONS_EXCEPT_SPECIFIED) -- there is no separate field for each.
  # It must be entirely omitted (null) for ALL_REGIONS, or the API rejects
  # the request.
  specified_regions = var.region_linking_mode == "ALL_REGIONS" ? null : var.linked_regions

  depends_on = [aws_securityhub_account.this]
}

# ---------------------------------------------------------------------------
# Findings notification — EventBridge rule matching findings at or above
# notification_minimum_severity, targeting the caller-supplied SNS topic.
#
# The topic's own policy must grant events.amazonaws.com Publish access —
# this module deliberately does not manage that policy. See variables.tf.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "findings" {
  count = local.need_notifications ? 1 : 0

  name        = "${var.name}-securityhub-findings"
  description = "Routes Security Hub findings at or above ${var.notification_minimum_severity} severity to SNS."

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = local.severities_included
        }
      }
    }
  })

  tags = local.common_tags

  depends_on = [aws_securityhub_account.this]
}

resource "aws_cloudwatch_event_target" "findings_to_sns" {
  count = local.need_notifications ? 1 : 0

  rule = aws_cloudwatch_event_rule.findings[0].name
  arn  = var.notification_sns_topic_arn
}
