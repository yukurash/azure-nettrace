# Outbound connection-target inference

ARM does not record "app X talks to database Y". This file defines how to infer it
from configuration — and how to do that **without ever exposing a secret**.

## Masking rules (apply BEFORE anything else)

These are hard requirements. Violating any of them means the output must not be shown.

1. Never print raw `appSettings` / `connectionStrings` JSON — not in the artifact,
   not in intermediate notes.
2. From any connection-string-like value keep only: **host (FQDN), port, database/
   container name**. Drop or mask everything else.
3. Mask pattern (case-insensitive):
   `(password|pwd|accountkey|sharedaccesskey|sharedaccesssignature|sig|client_secret|token)=<value>`
   → `$1=***MASKED***`
4. Any URL query string containing `sig=` or `token=` → replace the whole query with `***`.
5. Key Vault secret **values** are never read without explicit user consent in the
   current conversation; even with consent, extract the FQDN only and state
   "resolved via Key Vault reference (value not shown)".
6. The artifact must begin with the masking notice (see `output-format.md`).

## Inference sources, in priority order

| Priority | Source | Confidence | How |
|---|---|---|---|
| 1 | `connectionStrings` | **confirmed** | Parse `Server=`, `Data Source=`, `Host=`, `AccountEndpoint=`, `Endpoint=sb://` → FQDN |
| 2 | `appSettings` values | **confirmed** (full FQDN) / **inferred** (partial) | Match FQDN suffix table below |
| 3 | Key Vault references | **inferred** | `@Microsoft.KeyVault(SecretUri=https://{vault}.vault.azure.net/...)` → add the **vault itself** as a dependency node; the secret's target stays unknown unless the user opts in |
| 4 | Managed identity role assignments (Q11) | **inferred** | Data-plane roles (`Storage Blob Data *`, `Key Vault Secrets User`, `Cosmos DB Built-in Data *`, `Service Bus Data *`, `Search Index Data *`) → the role's scope is a likely target |
| 5 | Outbound PEs in the source VNet | **corroborating** | PEs in the same VNet whose targets match an inferred FQDN strengthen (not create) an edge |

## FQDN suffix → resource type map

| Suffix | Type |
|---|---|
| `.database.windows.net` | SQL Server |
| `.postgres.database.azure.com` | PostgreSQL Flexible |
| `.mysql.database.azure.com` | MySQL Flexible |
| `.documents.azure.com` | Cosmos DB |
| `.blob/.table/.queue/.file/.dfs.core.windows.net` | Storage account |
| `.vault.azure.net` | Key Vault |
| `.redis.cache.windows.net` | Azure Cache for Redis |
| `.servicebus.windows.net` | Service Bus / Event Hubs |
| `.azurewebsites.net` | another App Service / Function App |
| `.search.windows.net` | AI Search |
| `.openai.azure.com` / `.cognitiveservices.azure.com` | Azure OpenAI / AI Services |
| `.azurecr.io` | Container Registry |

Resolve FQDN first label → resource via ARG:
```kusto
resources
| where name =~ '{firstLabel}' and type in~ ('{expectedTypes}')
| project id, name, type, resourceGroup
```
If the resource is in another (inaccessible) subscription: keep the node as
`external: {fqdn}` with confidence unchanged and mark its target-side facts ⚪.

## Output contract (per inferred edge)

```
EDGE app --inferred--> sql-server X
  confidence: confirmed | inferred | corroborating
  evidence:   connectionStrings["MyDb"] (key name only — NEVER the value)
```

The dependency table in the artifact must carry `confidence` and `evidence` columns.
