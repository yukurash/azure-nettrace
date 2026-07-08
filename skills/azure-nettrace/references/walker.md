# Generic network walker

Type-independent edges that apply to (almost) every Azure resource. The adapter tells
you where the *type-specific* references live; this file tells you how to expand
everything else. Query IDs (Q1…Q12) refer to `queries.md`.

## Walk state

Keep a compact **facts list** in the conversation:

```
NODE app  <id> type=microsoft.web/sites  vnetSubnetId=<...>
NODE snet <id> nsg=<id> udr=<id> delegations=[Microsoft.Web/serverFarms] SE=[]
EDGE app --vnet-integration--> snet
FACT nsg <id> outbound-deny: [ {prio:100, port:1433, dst:*, access:Deny} ]
```

One line per node/edge/fact. No raw JSON.

## Walk limits

- **Depth ≤ 4** from the root (root=0). A hop = following one edge to a new resource.
- **Visited set**: never expand the same resource ID twice.
- **Fan-out guard**: if an edge yields > 10 nodes (e.g. a hub VNet with many PEs),
  list the count and only expand the ones on the path between root and its targets.

## Edge dictionary

| # | Edge | How to resolve |
|---|---|---|
| E1 | resource → **private endpoints pointing AT it** (inbound) | Q4 with the resource ID as `{targetId}` |
| E2 | resource → **subnet it egresses from** (outbound) | adapter-defined property path; fallback: regex-scan properties JSON for `"/subnets/"` |
| E3 | subnet → **NSG / route table / service endpoints / delegations / NAT gateway** | Q5 |
| E4 | NSG → relevant rules; route table → routes | Q6 (extract only rules touching the ports/prefixes on the traced path) |
| E5 | VNet → **peerings** and **custom DNS servers** | from the VNet body: `properties.virtualNetworkPeerings[]`, `properties.dhcpOptions.dnsServers` |
| E6 | PE → **NIC → private IP** | Q7 |
| E7 | PE → **DNS zone group → private DNS zone** | Q8 (az CLI — not in ARG) |
| E8 | private DNS zone → **VNet links** | Q9 — compare linked VNet IDs against the *source* VNet |
| E9 | target resource → **its inbound controls** | adapter (`publicNetworkAccess`, `networkAcls`, firewall/VNet rules) |

## Expansion order (from the root)

1. E2 (where does it egress?) → E3 → E4 on the egress subnet
2. E1 (who reaches it privately?) → E6, E7, E8 per PE
3. Phase 3 (inference) adds target nodes → per target: E9, then E1/E7/E8 *on the target*
4. E5 only when source and target sit in different VNets (peering/DNS path matters)

## Port map (used by E4 extraction and RF-01/02/08)

| Target type | Port |
|---|---|
| SQL Server / Azure SQL | 1433 |
| PostgreSQL | 5432 |
| MySQL | 3306 |
| Redis (TLS) | 6380 |
| HTTPS (Storage, Key Vault, Cosmos, App Service, APIM, AOAI, Search) | 443 |
| Service Bus / Event Hubs (AMQP-TLS) | 5671 (or 443 WebSockets) |

## DNS reasoning (feeds RF-04/05)

A target that is PE-only is reachable **only if** its FQDN resolves to the PE's private
IP from the source VNet. Chain to verify:

```
target has PE (E1 on target)
  → PE has a DNS zone group (E7) or a manual A record in the matching zone
  → the matching privatelink.* zone has a VNet link to the SOURCE VNet (E8)
  → (if the VNet uses custom DNS servers (E5): flag ⚪ — resolution path can't be
     verified from ARM alone; note the DNS server IPs)
```

Zone-name map: `privatelink.database.windows.net` (SQL), `privatelink.postgres.database.azure.com`,
`privatelink.mysql.database.azure.com`, `privatelink.blob.core.windows.net` (+table/queue/file/dfs),
`privatelink.vaultcore.azure.net` (KV), `privatelink.documents.azure.com` (Cosmos SQL API),
`privatelink.azurewebsites.net` (App Service), `privatelink.servicebus.windows.net`,
`privatelink.redis.cache.windows.net`, `privatelink.search.windows.net`, `privatelink.openai.azure.com`.
