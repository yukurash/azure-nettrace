# Adapter: networkAcls-family targets (Storage / Key Vault / Cosmos)

Types: `microsoft.storage/storageaccounts`, `microsoft.keyvault/vaults`,
`microsoft.documentdb/databaseaccounts`. All three share the `networkAcls` shape;
differences are noted inline.

## Common shape (from Q2 `properties`)

| Field | Meaning |
|---|---|
| `publicNetworkAccess` | `Enabled` / `Disabled` (Cosmos: also `SecuredByPerimeter`) |
| `networkAcls.defaultAction` | `Allow` / `Deny` — the RF-09 pivot |
| `networkAcls.ipRules[]` | public IP allowlist (compare with source outbound IPs) |
| `networkAcls.virtualNetworkRules[]` | subnet allowlist — requires the matching service endpoint on that subnet (RF-10) |
| `networkAcls.bypass` | `AzureServices` etc. — evaluate before concluding RF-09 |

Service-endpoint names for RF-10: `Microsoft.Storage`, `Microsoft.KeyVault`,
`Microsoft.AzureCosmosDB`.

## Private endpoints (Q4 on the account/vault ID)

`groupIds` matter here — one account can have several PE-able sub-resources:

| Type | groupIds → zone |
|---|---|
| Storage | `blob`→`privatelink.blob.core.windows.net`, `table`→`privatelink.table…`, `queue`, `file`, `dfs`, `web` |
| Key Vault | `vault` → `privatelink.vaultcore.azure.net` |
| Cosmos (SQL API) | `Sql` → `privatelink.documents.azure.com` |

When the source connects to `{account}.blob.core.windows.net`, the DNS chain
(RF-04/05) must be checked against the **blob** zone specifically — a PE that only
covers `file` does not help.

## Type-specific notes

- **Storage as root:** outbound side is empty (Storage initiates nothing);
  inbound exposure `publicNetworkAccess=Enabled` + `defaultAction=Allow` = 🟡 note.
- **Key Vault:** if the traced source has a Key Vault *reference* (Phase 3 source #3),
  add edge source→vault with port 443; `enableRbacAuthorization` is worth one fact
  line (auth failures masquerade as network issues).
- **Cosmos:** `isVirtualNetworkFilterEnabled` mirrors part of networkAcls;
  `SecuredByPerimeter` → mark perimeter facts ⚪ (NSP out of v1 scope).

## Facts to emit

```
FACT target st1 pna=Enabled acl.default=Deny ipRules=1 vnetRules=[snet-appsvc] bypass=AzureServices pe(blob)=[Approved] zoneLinked(blob)=true
```
