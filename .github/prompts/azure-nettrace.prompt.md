---
mode: agent
description: Trace the network connectivity of one Azure resource and produce an HTML reachability report.
tools: ['codebase', 'search', 'editFiles', 'runCommands', 'fetch']
---

Trace the network reachability of the Azure resource named **${input:resource:resource name or ID}**.

Output language: **${input:lang:ja or en}** · format **html** (default).

Follow the full pipeline, ground rules and rendering spec in
[`.github/agents/azure-nettrace.agent.md`](../agents/azure-nettrace.agent.md), which
reads the shared diagnostic logic under `skills/azure-nettrace/references/` and builds
the report from `skills/azure-nettrace/assets/report-template.html`.

Key reminders: **read-only** Azure calls only; **mask all secrets** before they appear
anywhere; walk source → egress subnet (NSG/UDR) → private endpoint → private DNS →
inferred targets → target-side firewalls; evaluate red flags RF-01…RF-12; write the
result to `out/trace-<resource>-<lang>.html`.
