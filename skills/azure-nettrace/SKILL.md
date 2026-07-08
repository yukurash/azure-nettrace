---
name: azure-nettrace
description: >
  Trace the network connectivity of a single Azure resource (any type: App Service,
  Function App, VM, AKS, SQL, Storage, Key Vault, APIM, ...). Walks VNet integration,
  subnets, NSGs, route tables (UDR), private endpoints, private DNS zones and
  target-side firewalls; infers outbound connection targets from app settings /
  connection strings / Key Vault references (secrets are always masked); outputs a
  Mermaid diagram + Markdown tables + a red-flag list of reachability blockers.
  Trigger on: connectivity trace, 接続性トレース, ネットワーク経路, 到達性診断,
  "why can't X reach Y", "App Service から DB につながらない", "trace network of <resource>".
---

# azure-nettrace — single-resource connectivity trace

You are tracing the network connectivity of **one** Azure resource and producing a
single Markdown artifact: Mermaid diagram + dependency tables + red-flag list.

## Ground rules (read first)

1. **Read-only.** Never run a mutating command. Only `az ... show/list`, `az graph query`,
   and read-only Azure MCP tools.
2. **Secrets are always masked.** Never print raw `appSettings` / `connectionStrings`
   JSON. Apply the masking rules in `references/connection-inference.md` **before**
   any value appears in your output or reasoning notes.
3. **Tool preference order:** Azure MCP tools (if available) → Azure MCP `extension az`
   passthrough → plain `az` CLI via Bash. All three run the same commands; use whichever
   is available. If `az graph query` fails with a `resource-graph` extension error, tell
   the user to run `az extension add --name resource-graph`.
4. **Unknown is unknown.** If a property cannot be read (permissions, API gap), report
   the affected check as ⚪ *unverified* with the reason. Never present a partial trace
   as a clean bill of health.
5. **Keep context lean.** Use the `project` clause in every KQL query. Do not paste
   full NSG rule sets or resource JSON into the conversation — extract only the fields
   the walk and the red-flag rules need.

## Pipeline

Work through the phases in order. Maintain a running **facts list** (nodes, edges,
properties) as compact bullet notes; Phase 5 evaluates rules against these facts.

### Phase 0 — Resolve the input
Run query **Q1** (`references/queries.md`) with the user's input (name or resource ID).
- 0 hits → ask the user to check the name / subscription context.
- 1 hit → record `id`, `type`, `kind`, `resourceGroup`, `location` as the root node.
- >1 hits → show the candidates (name, type, RG) and ask the user to pick one.

### Phase 1 — Select adapter
Match the resource `type` prefix against this table and read **only** the matching
adapter file from `references/adapters/`:

| `type` prefix | adapter |
|---|---|
| `microsoft.web/sites` (Web App & Function App) | `app-service.md` |
| `microsoft.compute/virtualmachines`, `virtualmachinescalesets` | `vm.md` |
| `microsoft.containerservice/managedclusters` | `aks.md` |
| `microsoft.sql/servers`, `microsoft.dbforpostgresql/`, `microsoft.dbformysql/` | `data-sql.md` |
| `microsoft.storage/storageaccounts`, `microsoft.keyvault/vaults`, `microsoft.documentdb/` | `data-storage.md` |
| `microsoft.apimanagement/service` | `apim.md` |
| `microsoft.cognitiveservices/accounts`, `microsoft.machinelearningservices/workspaces` | `foundry.md` |
| `microsoft.app/containerapps`, `microsoft.app/managedenvironments` | `container-apps.md` |
| `microsoft.cache/redis`, `microsoft.cache/redisenterprise` | `redis.md` |
| `microsoft.servicebus/namespaces`, `microsoft.eventhub/namespaces`, `microsoft.relay/namespaces` | `messaging.md` |
| `microsoft.containerregistry/registries` | `acr.md` |
| `microsoft.search/searchservices` | `ai-search.md` |
| anything else | `_fallback.md` |

The adapter tells you: where the resource's outbound subnet reference lives, where its
connection settings live, its inbound access properties, and any type-specific red flags.

### Phase 2 — Generic walk
Read `references/walker.md` and expand the graph from the root node using the generic
edge dictionary (PE reverse-lookup, subnet → NSG/UDR/service endpoints/delegations,
VNet → peerings/custom DNS, PE → NIC → private IP, PE → DNS zone group → private DNS
zone → VNet links). Respect the walk limits (depth ≤ 4, visited-set).

### Phase 3 — Infer outbound targets
Follow `references/connection-inference.md` using the config locations named by the
adapter. Attach a **confidence** (`confirmed` / `inferred` / `corroborating`) and an
**evidence** note (setting key name only — never the value) to every inferred edge.

### Phase 4 — Collect target-side facts
For each confirmed/inferred target, read its adapter (or `_fallback.md`) and collect:
`publicNetworkAccess`, `networkAcls` / firewall rules / VNet rules, its private
endpoints (Q4 against the target), and DNS zone linkage back to the source VNet.

### Phase 5 — Evaluate red flags
Read `references/redflags.md`. Evaluate every rule RF-01…RF-12 against the facts list.
Each rule yields: 🔴 blocker / 🟡 warning / ✅ pass / ⚪ unverified (+ reason).

### Phase 6 — Render output
Read `references/output-format.md` and produce the single Markdown artifact:
1. Header + masking notice
2. Mermaid diagram (node-ID rules from the template — alphanumeric IDs, quoted labels)
3. Dependency table (hop-by-hop, with confidence & evidence columns)
4. Red-flag list (🔴 first, then 🟡, then ⚪; ✅ summarized in one line)
5. "Unverified" appendix when anything could not be checked

## Failure handling

- MCP unavailable → fall back to Bash `az` silently; mention the fallback once.
- A single query failing must not abort the trace: mark the affected facts ⚪ and continue.
- If the root resource has **no network configuration at all** (e.g. a plain public
  Storage account with default networking), still render the artifact — inbound exposure
  (`publicNetworkAccess: Enabled` + `defaultAction: Allow`) is itself a 🟡 finding.
