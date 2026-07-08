# Adapter: AI Search

Type: `microsoft.search/searchservices`. A common target for Foundry / RAG workloads
and App Services; port 443.

## Network model

- `properties.publicNetworkAccess` (`enabled` / `disabled`)
- IP firewall: `properties.networkRuleSet.ipRules[]` (public model) — compare with the
  source's outbound IPs (RF-08 style). No VNet rules; private reach is via PE only.
- Private endpoints: Q4 on the service ID; zone `privatelink.search.windows.net`.
- `properties.sharedPrivateLinkResources` — **outbound** private links the search
  service opens to *its* data sources (Storage, SQL, Cosmos, AOAI). When AI Search is
  the trace root, enumerate these:
  `az search shared-private-link-resource list --service-name {name} -g {rg}` →
  each has a `privateLinkResourceId` (target) and a `status`
  (`Approved` / `Pending` / `Rejected`) — a Pending/Rejected shared PE is 🔴 for that
  data source (RF-07 analog on the outbound side).

## Directionality note

AI Search is unusual: it is both an **inbound** target (apps query it) and an
**outbound** client (it indexes Storage/SQL/etc. over *shared* private links). Trace
whichever direction the root implies; when it is the root, do both.

## Red flags

- Inbound: RF-06 (public disabled + no reachable PE), RF-04 on `search.windows.net`,
  RF-08 (IP rules miss source).
- Outbound (shared private links): RF-07 analog for each `Pending`/`Rejected` shared PE;
  note the target data source it blocks.

## Facts to emit

```text
FACT target search1 pna=disabled pe=[Approved] zoneLinked=true
FACT sharedPE search1 -> st-data (Storage) status=Pending   (RF-07 analog, outbound)
```
