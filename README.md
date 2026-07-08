# azure-nettrace

> **Status: work in progress** 🚧

A [Claude Code](https://claude.com/claude-code) **Agent Skill** that traces the network
connectivity of a **single Azure resource** and renders the result as a
**Mermaid diagram + Markdown tables + a red-flag list** of reachability blockers.

Give it one resource name (an App Service, VM, AKS cluster, Function App, SQL server,
Storage account, APIM instance, ...) and it walks:

```
resource → VNet integration subnet → NSG / route table (UDR)
        → private endpoints → private DNS zones (VNet links)
        → inferred outbound targets (from app settings / connection strings / Key Vault references)
        → target-side firewalls (networkAcls / publicNetworkAccess / DB firewall rules)
```

…and tells you not just *what is connected*, but **why a connection may be broken**
(missing private DNS VNet link, NSG deny, unapproved private endpoint, DB firewall
not allowing the integration subnet, and more).

## Why another visualizer?

Existing tools ([azure-resource-visualizer](https://github.com/microsoft/azure-skills),
Network Watcher topology) draw *a whole resource group or network*. This skill answers a
different question: **"why can't this one resource reach that one?"** — single-resource
walk, connection-target inference, and reachability diagnostics fused into one output.

## Requirements

- Claude Code with the [Azure MCP server](https://github.com/Azure/azure-mcp) (recommended)
  or plain Azure CLI as a fallback
- Azure CLI ≥ 2.60 logged in (`az login`), `resource-graph` extension
- Reader access to the target subscription

## Install

_Coming soon — see `skills/azure-nettrace/`._

## Security

All secrets in traced configuration are masked in output. This repository enforces
secret scanning (gitleaks) on every push and PR; examples are fully sanitized.

## License

MIT
