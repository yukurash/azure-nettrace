# Adapter: SQL-family targets

Types: `microsoft.sql/servers` (+`/databases`), `microsoft.dbforpostgresql/flexibleservers`,
`microsoft.dbformysql/flexibleservers`.

These are usually **targets**, but the same adapter serves them as trace roots
(then the "inbound" section is the interesting part and Phase 3 is usually empty).

## Azure SQL (`microsoft.sql/servers`)

| Aspect | Where |
|---|---|
| Public access | `az sql server show` → `publicNetworkAccess` |
| IP firewall | `az sql server firewall-rule list` (note `0.0.0.0–0.0.0.0` = "Allow Azure services" → RF-08 special case) |
| VNet rules | `az sql server vnet-rule list` → `virtualNetworkSubnetId` (pair with RF-10: subnet needs `Microsoft.Sql` service endpoint) |
| Private endpoints | Q4 on the server ID; zone `privatelink.database.windows.net`; port 1433 |
| Outbound (as root) | `properties.restrictOutboundNetworkAccess` + outbound firewall rules (rarely used) |

A database resource (`servers/databases`) inherits server networking — trace the server.

## PostgreSQL / MySQL Flexible Server

| Aspect | Where |
|---|---|
| Network mode | `properties.network.publicNetworkAccess`; **VNet-injected** if `properties.network.delegatedSubnetResourceId != null` (no PE in that mode — the server itself lives in the subnet) |
| Private DNS (VNet-injected) | `properties.network.privateDnsZoneArmResourceId` → run Q9 on that zone |
| IP firewall (public mode) | `az postgres|mysql flexible-server firewall-rule list` |
| Private endpoints (public-with-PE mode) | Q4; zones `privatelink.postgres.database.azure.com` / `privatelink.mysql.database.azure.com`; ports 5432 / 3306 |

VNet-injected note: source and server must share the VNet or a peering path (E5),
and the delegated subnet's delegation must match (`Microsoft.DBforPostgreSQL/flexibleServers`
etc.) — RF-12 variant.

## Facts to emit (target-side)

```
FACT target sql1 pna=Disabled fwRules=0 vnetRules=0 pe=[Approved@snet-pe] zoneLinked=false
```

Exactly what RF-06/07/08/10 and the DNS chain (RF-04/05) need — nothing more.
