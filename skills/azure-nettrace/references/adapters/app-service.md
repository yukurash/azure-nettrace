# Adapter: App Service / Function App (`microsoft.web/sites`)

Covers Web Apps and Function Apps (`kind` contains `functionapp`). Logic Apps
Standard (`kind` contains `workflowapp`) behaves the same for networking.

## Outbound edges

| What | Where |
|---|---|
| Regional VNet integration subnet | `properties.virtualNetworkSubnetId` (null = no integration) |
| Route-all flag | `{id}/config/web` → `properties.vnetRouteAllEnabled` (see Q3). Also overridable by app setting `WEBSITE_VNET_ROUTE_ALL=1` |
| Outbound public IPs (used when traffic does NOT go through the VNet) | `properties.outboundIpAddresses` / `possibleOutboundIpAddresses` |

Interpretation:
- `virtualNetworkSubnetId == null` → all egress from public outbound IPs; skip E3/E4
  on the source side but keep them for target-side reasoning (RF-08 uses outbound IPs).
- Integration present + `vnetRouteAllEnabled == false` → **only RFC1918 traffic**
  enters the VNet; public FQDN targets egress from the public IPs → feeds RF-11.

## Connection settings (Phase 3 input)

1. `az webapp config connection-string list` (or Q2 `siteConfig` when readable)
2. `az webapp config appsettings list` — scan **values** for FQDN patterns and
   Key Vault references; scan **keys** for hints (`*_ENDPOINT`, `*_URL`, `*_CONN*`)
3. Function Apps: `AzureWebJobsStorage`, `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING`
   are Storage connection strings — the app's own storage dependency, include it.
4. `identity` block → Q11 for role-assignment-based inference.

⚠️ Everything read here passes through `connection-inference.md` masking before use.

## Inbound controls

- `properties.publicNetworkAccess` (`Enabled` / `Disabled`)
- Access restrictions: `{id}/config/web` → `properties.ipSecurityRestrictions[]`
  (and `scmIpSecurityRestrictions[]`)
- Private endpoints: Q4 against the site ID (zone: `privatelink.azurewebsites.net`)

## Type-specific red flags

- RF-11 (route-all off while a target is PE-only) — evaluate whenever integration exists.
- RF-12 variant: integration subnet must be delegated to `Microsoft.Web/serverFarms`.
- Warm hint (🟡): `WEBSITE_DNS_SERVER` app setting present → custom DNS in use; DNS
  chain becomes ⚪ unverified unless the custom server forwards to 168.63.129.16.
