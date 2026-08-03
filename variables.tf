# ---------------------------------------------------------------------------
# Core identity
# ---------------------------------------------------------------------------

variable "name" {
  description = "Logical name for this deployment. Security Hub itself is an account+region singleton (there's only ever one per account/region), so this only prefixes the child resources this module creates — the findings EventBridge rule, primarily."
  type        = string
  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 50
    error_message = "name must be 1–50 characters."
  }
}

# ---------------------------------------------------------------------------
# Account enablement
#
# Unlike most resources this catalog wraps, Security Hub is a per-account
# singleton that may already be centrally enabled via AWS Organizations
# delegated administration. Creating aws_securityhub_account again in a
# member account that's already covered by an org-wide Security Hub admin
# will error. manage_account lets a member-account caller skip that
# resource entirely and only manage standards/notifications against the
# Hub the org admin already enabled.
# ---------------------------------------------------------------------------

variable "manage_account" {
  description = "Create the aws_securityhub_account resource (enables Security Hub in this account/region). Set to false when Security Hub is centrally enabled via AWS Organizations delegated administration and this module should only manage standards subscriptions / notifications against the existing Hub."
  type        = bool
  default     = true
}

variable "auto_enable_controls" {
  description = "Automatically enable new controls that AWS adds to already-enabled standards, without requiring a re-apply. Ignored when manage_account = false."
  type        = bool
  default     = true
}

variable "control_finding_generator" {
  description = "Whether findings are generated per security control (STANDARD_CONTROL, deduplicated across standards — AWS's current recommendation) or per standard-check (SECURITY_CONTROL, one finding per standard even for the same underlying control). Ignored when manage_account = false."
  type        = string
  default     = "SECURITY_CONTROL"
  validation {
    condition     = contains(["STANDARD_CONTROL", "SECURITY_CONTROL"], var.control_finding_generator)
    error_message = "control_finding_generator must be STANDARD_CONTROL or SECURITY_CONTROL."
  }
}

# ---------------------------------------------------------------------------
# Standards subscriptions
#
# Short keys map to full standards ARNs in locals.tf (region-qualified) —
# same short-name-to-full-identifier pattern as the sibling VPC module's
# interface_endpoints variable.
# ---------------------------------------------------------------------------

variable "standards" {
  description = "Security standards to subscribe to, by short key: \"aws-foundational-security-best-practices\", \"cis-aws-foundations\", \"pci-dss\", \"nist-800-53\". Fintech-safe default enables the two most broadly required frameworks."
  type        = list(string)
  default     = ["aws-foundational-security-best-practices", "cis-aws-foundations"]

  validation {
    condition = alltrue([
      for s in var.standards :
      contains(["aws-foundational-security-best-practices", "cis-aws-foundations", "pci-dss", "nist-800-53"], s)
    ])
    error_message = "Each entry in standards must be one of: aws-foundational-security-best-practices, cis-aws-foundations, pci-dss, nist-800-53."
  }
}

# ---------------------------------------------------------------------------
# Cross-region finding aggregation
# ---------------------------------------------------------------------------

variable "enable_finding_aggregator" {
  description = "Aggregate findings from other regions into this one (a single pane of glass across a multi-region footprint). Only one aggregator can exist per account — creating this in more than one region's module call will conflict."
  type        = bool
  default     = false
}

variable "region_linking_mode" {
  description = "Which regions feed the aggregator: ALL_REGIONS, ALL_REGIONS_EXCEPT_SPECIFIED, or SPECIFIED_REGIONS. Ignored when enable_finding_aggregator = false."
  type        = string
  default     = "ALL_REGIONS"
  validation {
    condition     = contains(["ALL_REGIONS", "ALL_REGIONS_EXCEPT_SPECIFIED", "SPECIFIED_REGIONS"], var.region_linking_mode)
    error_message = "region_linking_mode must be ALL_REGIONS, ALL_REGIONS_EXCEPT_SPECIFIED, or SPECIFIED_REGIONS."
  }
}

variable "linked_regions" {
  description = "Region names to include (SPECIFIED_REGIONS) or exclude (ALL_REGIONS_EXCEPT_SPECIFIED). Ignored for ALL_REGIONS."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Findings notification — routes findings at or above a severity threshold
# to an existing SNS topic via EventBridge.
#
# This module does NOT create or manage the SNS topic's policy — that
# would fight with the sibling terraform-aws-sns module's own policy
# management for the same topic (two modules independently overwriting
# one aws_sns_topic_policy resource causes perpetual plan diffs). Grant
# events.amazonaws.com publish access on the target topic yourself, e.g.
# via terraform-aws-sns's policy_principals. See README for the exact
# statement.
# ---------------------------------------------------------------------------

variable "notification_sns_topic_arn" {
  description = "ARN of an existing SNS topic to receive findings at or above notification_minimum_severity. Leave empty (default) to skip creating the EventBridge rule entirely. The topic's own policy must separately grant events.amazonaws.com permission to publish — this module does not manage that policy."
  type        = string
  default     = ""
}

variable "notification_minimum_severity" {
  description = "Minimum finding severity that triggers a notification: INFORMATIONAL, LOW, MEDIUM, HIGH, or CRITICAL. Ignored when notification_sns_topic_arn is empty."
  type        = string
  default     = "HIGH"
  validation {
    condition     = contains(["INFORMATIONAL", "LOW", "MEDIUM", "HIGH", "CRITICAL"], var.notification_minimum_severity)
    error_message = "notification_minimum_severity must be one of: INFORMATIONAL, LOW, MEDIUM, HIGH, CRITICAL."
  }
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags merged onto every taggable resource (the EventBridge rule; Security Hub's own resources don't support tagging as of this module's provider pin)."
  type        = map(string)
  default     = {}
}
