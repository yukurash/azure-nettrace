# Adapter: Data Factory / Synapse

Types: `microsoft.datafactory/factories`, `microsoft.synapse/workspaces`.
Both use a **managed VNet** with **managed private endpoints** to reach data stores —
a model the generic fallback does not understand.

## The managed-VNet + managed-PE model

Egress to data sources does not come from a subnet you own; it comes from the service's
managed VNet via **managed private endpoints** the service creates to each source:

- Data Factory: `az datafactory managed-private-endpoint list --factory-name {n} -g {rg}
  --managed-virtual-network-name default` → each has `privateLinkResourceId` (target)
  and a connection state.
- Synapse: `az synapse managed-private-endpoints list --workspace-name {n} -g {rg}`.

For each managed PE, the **target** must approve the connection
(`status == Approved`); `Pending`/`Rejected` → 🔴 the pipeline/notebook can't reach that
source over private link (RF-07 analog, outbound).

## Inbound to the service itself

| Aspect | Where |
|---|---|
| Public access | DF: `properties.publicNetworkAccess`; Synapse: `properties.publicNetworkAccess` + `properties.managedVirtualNetwork` |
| Private endpoints (to the service) | Q4. DF zones: `privatelink.datafactory.azure.net` (+ `privatelink.adf.azure.com` for the portal). Synapse zones: `privatelink.sql.azuresynapse.net` (SQL), `privatelink.dev.azuresynapse.net` (dev), `privatelink.azuresynapse.net` |
| Synapse firewall | `az synapse workspace firewall-rule list` (IP allowlist for the SQL/dev endpoints) + `properties.managedVirtualNetwork == 'default'` |

## Integration runtime (Data Factory)

`az datafactory integration-runtime list` — a **self-hosted IR** runs on a VM/on-prem
you control; when present, egress for those activities originates from that host, not the
managed VNet → trace the IR host's network instead (note it explicitly).

## Red flags

- Managed PE to a data source `Pending`/`Rejected` (RF-07 analog) — 🔴 per source.
- RF-06 (service public access disabled + no reachable PE to the service).
- RF-04 on each service PE zone.
- Synapse: workspace firewall denies the caller's IP with no PE → 🔴.

## Facts to emit

```text
FACT dataplat adf1 managedVnet=default pna=Disabled pe=[Approved@snet-pe]
FACT managedPE adf1 -> contoso-sql (SQL) status=Approved
FACT managedPE adf1 -> contoso-st (Storage) status=Pending   (RF-07 analog, outbound)
FACT ir adf1 selfHosted=IR-onprem  (egress from that host, trace separately)
```
