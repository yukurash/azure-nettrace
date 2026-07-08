# Adapter: Azure Cache for Redis

Types: `microsoft.cache/redis` (classic) and `microsoft.cache/redisenterprise`.
Almost always a **target**; port 6380 (TLS), 6379 (non-TLS, usually disabled).

## Classic Redis (`microsoft.cache/redis`)

Two mutually exclusive network models — determine which is in use first:

| Model | Signal |
|---|---|
| **VNet injection** (classic) | `properties.subnetId != null` — the cache lives inside your subnet; no PE. Reachability = source can route to that subnet + NSG allows 6380. |
| **Private Endpoint** | Q4 on the cache ID; zone `privatelink.redis.cache.windows.net`. `properties.publicNetworkAccess` should be `Disabled`. |

Other facts:

- `properties.publicNetworkAccess` (`Enabled` / `Disabled`)
- Firewall rules (public model): `az redis firewall-rules list -n {name} -g {rg}` →
  `startIP`–`endIP` ranges (compare with source outbound IPs, RF-08 style)
- `properties.enableNonSslPort` — if true and source uses 6379, note it (🟡)

VNet-injection caveat (RF-12 variant): the injected subnet must contain **only** the
cache; a mismatched or shared subnet breaks provisioning/routing.

## Redis Enterprise (`microsoft.cache/redisenterprise`)

PE-only model in practice: Q4 on the cluster ID, same zone family; check
`properties.publicNetworkAccess`. No classic VNet injection.

## Red flags

- RF-06 (public disabled + no reachable PE), RF-04 (zone not linked to source VNet),
  RF-01 (NSG denies 6380 outbound), RF-08 (firewall rules miss source IP — public model).
- VNet-injection model: RF-01/RF-03 on the injected subnet's NSG/route table.

## Facts to emit

```text
FACT target redis1 model=PrivateEndpoint pna=Disabled pe=[Approved@snet-pe] zoneLinked=true port=6380
FACT target redis2 model=VnetInjection subnet=snet-redis nsgAllows6380=true
```
