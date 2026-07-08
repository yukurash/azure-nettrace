# Adapter: Microsoft Foundry / Azure AI

Covers the two resource families behind Microsoft Foundry (Azure AI Foundry):

- `microsoft.cognitiveservices/accounts` — AI Services / Azure OpenAI endpoints
  (kinds: `AIServices`, `OpenAI`, `CognitiveServices`, ...)
- `microsoft.machinelearningservices/workspaces` — Foundry **hubs** and **projects**
  (`kind`: `Hub` / `Project` / `Default`)

Foundry connectivity is more than plain network deps: a hub links a set of associated
resources (Storage / Key Vault / ACR / AI Search / Azure OpenAI), and it can run under a
**managed VNet**. Trace those, not just the subnet/PE.

## Cognitive Services / Azure OpenAI (`microsoft.cognitiveservices/accounts`)

| Aspect | Where |
|---|---|
| Public access | `properties.publicNetworkAccess` (`Enabled` / `Disabled`) |
| Network ACLs | `properties.networkAcls.{defaultAction, ipRules, virtualNetworkRules}` (RF-09/10) |
| Private endpoints | Q4 on the account ID. Zones by kind: `privatelink.openai.azure.com` (OpenAI), `privatelink.cognitiveservices.azure.com`, `privatelink.services.ai.azure.com` (unified AI Services); port 443 |
| Custom subdomain | `properties.customSubDomainName` — required for PE + AAD auth; if missing, PE-based name resolution will not work (note as a warning) |
| Identity | `identity.principalId` → Q11 (e.g. a hub/app calling this endpoint via a data-plane role) |

As a **target** of another resource (App Service → AOAI): the FQDN suffix map in
`connection-inference.md` already routes `.openai.azure.com` / `.cognitiveservices.azure.com`
here — collect the inbound facts above.

## Foundry hub / project (`microsoft.machinelearningservices/workspaces`)

Determine the role first: `kind == 'Hub'`, `'Project'`, or `'Default'`
(project also carries `properties.hubResourceId` pointing at its hub).

| Aspect | Where |
|---|---|
| Public access | `properties.publicNetworkAccess` |
| **Managed VNet** | `properties.managedNetwork.isolationMode` (`Disabled` / `AllowInternetOutbound` / `AllowOnlyApprovedOutbound`) + `properties.managedNetwork.outboundRules` |
| Private endpoints (to the hub) | Q4 on the workspace ID. Zones: `privatelink.api.azureml.ms` **and** `privatelink.notebooks.azure.net` — both are needed; a PE covering only one leaves the other unresolved (RF-05-style warning) |
| **Associated resources** | `properties.storageAccount`, `properties.keyVault`, `properties.containerRegistry`, `properties.applicationInsights` — add each as a dependency node and run its own adapter (data-storage / data-sql / ...) |
| **Connections** (to AOAI / AI Search / etc.) | Not in the workspace body — list via `az ml connection list -w {name} -g {rg}` (or REST `{workspaceId}/connections`). Each `target` is an FQDN → route through `connection-inference.md`. Confidence: confirmed (explicit connection). |
| Identity | `identity.principalId` → Q11 |

### Reasoning notes

- `isolationMode == 'AllowOnlyApprovedOutbound'` means egress is limited to the managed
  network's `outboundRules`. If a connection target (e.g. a Storage account or AOAI) is
  **not** covered by an outbound rule (FQDN / PE / service-tag rule), flag it 🔴 — the
  managed VNet will block it even though the target's own firewall looks fine.
- A project inherits much of its hub's networking; when tracing a project, also pull the
  hub (`hubResourceId`) and note shared associated resources.

## Type-specific red flags

- RF-06 (public disabled + no reachable PE) on both families.
- RF-04 (private DNS zone not linked) on each of the two AzureML zones and the
  Cognitive Services zone.
- Managed-VNet approved-outbound gap (above) — reported as an RF-06 variant with the
  managed network named as the blocker.

## Facts to emit

```text
FACT foundry hub1 kind=Hub pna=Disabled managedVnet=AllowOnlyApprovedOutbound
FACT assoc hub1 -> st1 (Storage), kv1 (KeyVault), acr1 (ACR)
FACT connection hub1 -> contoso-aoai.openai.azure.com (confirmed: workspace connection)
FACT pe hub1 zones=[api.azureml.ms:linked, notebooks.azure.net:NOT linked]  (RF-04 on notebooks)
```
