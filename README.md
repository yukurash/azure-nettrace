# azure-nettrace

**English** · [日本語](README.ja.md)

> **Status: work in progress** 🚧

A [Claude Code](https://claude.com/claude-code) **Agent Skill** that traces the network
connectivity of a **single Azure resource** and renders it as an **interactive HTML
report** — a wired path diagram with official Azure icons, a red-flag list of
reachability blockers, and **click-to-inspect** panels for every resource.

Give it one resource name (an App Service, VM, AKS cluster, Function App, SQL server,
Storage account, APIM instance, …) and it walks:

```text
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
walk, connection-target inference, and reachability diagnostics fused into one report.

## Highlights

- **Verdict first** — one plain sentence: can the resource reach its target, and if not, the root cause.
- **Wired path diagram** with the **official Microsoft Azure icons** (opt-in) and a broken hop shown in red.
- **Click any resource** to inspect its network settings — NSG rules, subnet config, private-endpoint state, DNS VNet links, SQL/Storage firewalls, and more.
- **~20 resource types** with dedicated adapters (App Service, Functions, VM, AKS, Container Apps, SQL/PG/MySQL, Storage/Key Vault/Cosmos, Redis, Service Bus/Event Hubs, ACR, AI Search, Foundry, API Management, Application Gateway, Front Door, **Azure Firewall**, Data Factory/Synapse, …); any other type traces via a generic fallback.
- **Output language** `en` / `ja`; **light/dark**; fully **self-contained** (no internet needed to view).

## Requirements

- Claude Code with the [Azure MCP server](https://github.com/Azure/azure-mcp) (recommended)
  or plain Azure CLI as a fallback
- Azure CLI ≥ 2.60 signed in (`az login`), `resource-graph` extension
- Reader access to the target subscription

## Install

Link the skill into your Claude Code skills directory:

```powershell
# Windows
New-Item -ItemType Junction -Path "$HOME\.claude\skills\azure-nettrace" `
  -Target "<repo>\skills\azure-nettrace"
```

```bash
# macOS / Linux
ln -s "<repo>/skills/azure-nettrace" "$HOME/.claude/skills/azure-nettrace"
```

Add the Azure MCP server and sign in with the Azure CLI:

```bash
az login
az extension add --name resource-graph
claude mcp add azure -- npx -y @azure/mcp@latest server start --read-only
```

Then ask Claude Code:

> **trace the network connectivity of `<your-app-service-name>`**

## Output

By default the skill writes a **self-contained interactive HTML report** to `out/`.
Open it in a browser (light/dark aware, no internet needed):

- a **verdict** band, a **wired path diagram**, a **red-flag** panel and a **dependency table**;
- **click a node** (or a branch such as an NSG) to open an inspector with that resource's
  network settings.

Options:

- **`lang`** — `en` or `ja` (the skill asks if you don't say).
- **`format`** — `html` (default) or `markdown` (inline Mermaid + tables).
- **`iconStyle`** — `builtin` (default, license-safe icons) or `official`. For the
  **official** Microsoft Azure architecture icons, download the set into
  `skills/azure-nettrace/assets/azure-icons/` (gitignored) and pass `iconStyle: official`
  — see [`references/output-html.md`](skills/azure-nettrace/references/output-html.md).

`assets/report-template.html` is a runnable reference report you can open directly.

## Examples

See [`examples/`](examples/) for sanitized sample output:

- [healthy trace](examples/appservice-to-sql-healthy.md) — 0 blockers
- [broken private DNS](examples/appservice-to-sql-broken-dns.md) — 🔴 RF-04 (the classic
  "the private endpoint is set up but it still can't connect" case)

Reproduce them yourself with the [test environment](test-infra/).

## Security

All secrets in traced configuration are masked in output. The official Azure icon set is
**never** committed (gitignored). This repository enforces secret scanning (gitleaks) on
every push and PR; examples are fully sanitized.

## License

MIT
