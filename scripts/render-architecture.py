#!/usr/bin/env python3
"""Render an AWS architecture diagram from a Terraform plan JSON.

Reads the output of `terraform show -json plan.binary` from the
`examples/complete/` plan, and renders Security Hub, its subscribed
standards, cross-region finding aggregation (if enabled), and the
EventBridge -> SNS findings-notification path (if enabled), then writes
a PNG.

This script is invoked from `.github/workflows/architecture-diagram.yml`
on every PR and on push to main. The committed PNG lives at
`docs/architecture.png` and is embedded in README.md between
`<!-- BEGIN_ARCH -->` / `<!-- END_ARCH -->` markers.

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>

Example:
    python scripts/render-architecture.py examples/complete/plan.json docs/architecture
        -> writes docs/architecture.png
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.integration import SNS, Eventbridge
from diagrams.aws.security import SecurityHub, SecurityHubFinding


# ----------------------------------------------------------------------------
# Resource collection
# ----------------------------------------------------------------------------


def load_resources(plan_path: Path) -> list[dict]:
    """Flatten every resource (root + child modules) from a Terraform plan JSON."""
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


def values(r: dict) -> dict:
    return r.get("values", {}) or {}


# ----------------------------------------------------------------------------
# Render
# ----------------------------------------------------------------------------


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)
    by_type: dict[str, list[dict]] = defaultdict(list)
    for r in resources:
        by_type[r["type"]].append(r)

    standards = by_type.get("aws_securityhub_standards_subscription", [])
    has_aggregator = bool(by_type.get("aws_securityhub_finding_aggregator"))
    event_rules = by_type.get("aws_cloudwatch_event_rule", [])
    sns_topics = by_type.get("aws_sns_topic", [])

    graph_attr = {"splines": "spline", "pad": "0.5"}

    with Diagram(
        name="Security Hub",
        filename=str(out_no_ext),
        show=False,
        direction="LR",
        graph_attr=graph_attr,
    ):
        hub = SecurityHub("Security Hub\n(account/region)")

        with Cluster("Subscribed standards"):
            standard_nodes = []
            for s in standards:
                arn = values(s).get("standards_arn", "standard")
                # Short label: the standard slug between "standards/" and "/v/".
                label = arn.split("standards/")[-1].split("/v/")[0] if "standards/" in arn else arn
                standard_nodes.append(SecurityHubFinding(label))
            if standard_nodes:
                hub >> Edge(label="subscribes") >> standard_nodes

        if has_aggregator:
            hub >> Edge(label="aggregates findings\nfrom other regions", style="dashed") >> SecurityHub("Aggregated view")

        if event_rules and sns_topics:
            rule_name = values(event_rules[0]).get("name", "findings rule")
            bridge = Eventbridge(rule_name)
            topic_name = values(sns_topics[0]).get("name", "findings topic")
            topic = SNS(topic_name)
            hub >> Edge(label="findings\n(>= min severity)") >> bridge >> topic


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <plan.json> <output-path-no-ext>", file=sys.stderr)
        sys.exit(1)

    plan_path = Path(sys.argv[1])
    out_no_ext = Path(sys.argv[2])
    out_no_ext.parent.mkdir(parents=True, exist_ok=True)

    render(plan_path, out_no_ext)


if __name__ == "__main__":
    main()
