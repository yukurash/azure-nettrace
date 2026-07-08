# Adapter: misc PaaS targets

Compact adapters for smaller PaaS services that are common connection targets. All share
the pattern: `publicNetworkAccess` + some form of firewall/ACL + Private Endpoint. Only
the service-specific fields and PE zones differ. Port 443 unless noted.

## Event Grid (`microsoft.eventgrid/topics`, `.../domains`, `.../namespaces`)

- `properties.publicNetworkAccess`; `properties.inboundIpRules[]` (IP allowlist)
- PE: Q4; zone `privatelink.eventgrid.azure.net`
- Namespaces (MQTT/pull) add `privatelink.ts.eventgrid.azure.net`
- Red flags: RF-06, RF-04, RF-08 (inbound IP rules miss source).

## App Configuration (`microsoft.appconfiguration/configurationstores`)

- `properties.publicNetworkAccess`; PE zone `privatelink.azconfig.io`
- Often referenced by App Service/Functions via a `.azconfig.io` endpoint → inbound trace.
- Red flags: RF-06, RF-04.

## SignalR / Web PubSub (`microsoft.signalrservice/signalr`, `.../webpubsub`)

- `properties.publicNetworkAccess`; `properties.networkACLs` (note: **`networkACLs`**,
  with `defaultAction` + `publicNetwork`/`privateEndpoints` allow lists)
- PE: Q4; zones `privatelink.service.signalr.net` / `privatelink.webpubsub.azure.com`
- Red flags: RF-06, RF-04, RF-09 analog on `networkACLs`.

## Load Balancer (`microsoft.network/loadbalancers`)

Not a firewalled target — a path element. Read when tracing VM/AKS ingress:

- `properties.frontendIPConfigurations[]` (public vs internal + subnet)
- `properties.backendAddressPools[]` → backend NICs/IPs (downstream nodes)
- `properties.probes[]` — an unhealthy probe (wrong port/path) makes the backend look
  unreachable though the network is fine (🟡, note as health not network)
- Internal LB: reachability = source can route to the frontend subnet + NSG allows the
  rule port.

## VPN / ExpressRoute Gateway (`microsoft.network/virtualnetworkgateways`)

Hybrid ingress/egress. Read when a target is on-prem or across a gateway:

- `properties.gatewayType` (`Vpn` / `ExpressRoute`), `properties.bgpSettings`
- The gateway lives in the `GatewaySubnet`; routes to on-prem prefixes propagate via BGP
  or the gateway's connections (`az network vpn-connection list`).
- Reachability to an on-prem target is **out of ARM's data**: note the advertised
  prefixes and mark the actual on-prem reach ⚪ (verify with Connection Monitor).

## Static Web Apps (`microsoft.web/staticsites`)

- `properties.publicNetworkAccess`; enterprise-grade edge can use PE (zone
  `privatelink.azurestaticapps.net`) and **linked backends** (App Service / Functions /
  Container Apps / APIM) via `az staticwebapp backends show`.
- Trace each linked backend with its own adapter.
- Red flags: RF-06/RF-04 on the SWA PE; backend chain per linked backend.

## Facts to emit

```text
FACT target eg1 (EventGrid) pna=Disabled pe=[Approved] zone=eventgrid.azure.net linked=true
FACT target ac1 (AppConfig) pna=Disabled pe=[Approved] zone=azconfig.io linked=true
FACT lb lb1 internal frontendSubnet=snet-lb backends=[vm1,vm2] probe=OK
```
