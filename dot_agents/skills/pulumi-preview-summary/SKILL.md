---
name: pulumi-preview-summary
description: Run `mise run preview` and produce a structured analysis of pending Pulumi changes — counts by type, root-cause identification, cascade tracing, and risk flags. Use when asked to "summarize the Pulumi preview", "what's changing in Pulumi", "run preview and explain", or "how many Pulumi changes are there".
---

<objective>
Run the Pulumi preview and produce a concise, structured analysis: change counts, root-cause identification, cascade tracing, and risk flags. Do not dump raw output — synthesize it.
</objective>

<process>
**Step 1 — Run the preview**

```bash
rtk mise run preview 2>&1
```

Capture full output. If the command fails (missing stack, auth error, missing env), report the error and stop.

**Step 2 — Count and categorize changes**

Parse the summary line at the bottom of preview output:
- `+` = creates
- `~` = updates  
- `+-` = replaces (destroy + create, order matters)
- `-` = deletes
- `=` = unchanged

Report the total pending changes and unchanged count.

**Step 3 — Group changes by resource type**

Scan the resource lines and group by Pulumi type (e.g. `aws:ec2/instance:Instance`, `aws:cloudwatch/metricAlarm:MetricAlarm`, `aws:iam/rolePolicy:RolePolicy`). Within each group, note what's changing at a high level — don't list every property diff unless it's material.

**Step 4 — Identify root causes and cascades**

Replaces (`+-`) are almost always the root cause of unexpected change counts. When a key resource (EC2 instance, security group, IAM role) is replaced:
- Its ARN/ID becomes `[unknown]` during plan
- Any resource referencing that ID shows as update or replace
- Lambda env vars, volume attachments, IAM policies, and ALB rules cascade

Name the root cause resource(s) and trace what cascades from them. This is the most important part of the analysis.

**Step 5 — Flag risky changes**

Call out explicitly:
- Any `+-` replace on stateful resources (EC2 instances, RDS clusters, EBS volumes, S3 buckets)
- IAM policy statements being removed (permission narrowing may break running services)
- Lambda function replaces or code changes
- Security group or VPC changes (network connectivity impact)
- DNS or ALB changes (traffic routing impact)

**Step 6 — Note monitoring/metric changes**

If CloudWatch metric names, alarm thresholds, or dashboard structures are changing, note the before/after naming so it's clear whether dashboards and alarms will stay coherent.

**Step 7 — Produce the summary**

Format:

```
**N changes** (X creates, Y updates, Z replaces, W deletes) | M unchanged

### Root cause
[One sentence on what's driving the bulk of changes]

### Creates (+N)
[Grouped by type with brief description of each group]

### Updates (~N)
[Grouped by type with what's materially changing]

### Replaces (+-N) ⚠️
[Every replace named explicitly — these are risky]

### Deletes (-N)
[Named explicitly]

### Risk flags
[Bulleted list of specific concerns — or "None identified" if clean]
```

Omit sections with zero items.
</process>

<success_criteria>
- Change counts match what Pulumi reports
- Root cause of any unexpected count is named
- Every replace is called out explicitly
- IAM policy removals are flagged
- The user can decide whether to apply without reading raw preview output
</success_criteria>
