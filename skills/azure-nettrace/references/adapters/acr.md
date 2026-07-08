# Adapter: Container Registry (ACR)

Type: `microsoft.containerregistry/registries`. A frequent dependency of AKS,
Container Apps, and App Service (image pulls); port 443.

## Network model

- `properties.publicNetworkAccess` (`Enabled` / `Disabled`)
- **`properties.networkRuleSet`** (Premium SKU only): `defaultAction`, `ipRules[]`
  — note there are **no** VNet rules for ACR; VNet reach is via Private Endpoint only
- `properties.networkRuleBypassOptions` (`AzureServices` / `None`) — evaluate before
  concluding a block (AKS/tasks may bypass)
- Private endpoints: Q4 on the registry ID; zone `privatelink.azurecr.io`.
  **Data endpoints**: with PE, ACR also needs per-region data-endpoint DNS records
  (`{registry}.{region}.data.privatelink.azurecr.io`) — a PE without the data records
  resolves the login server but fails on blob pull (🟡 RF-05 variant; check
  `properties.dataEndpointEnabled`).

## SKU note

`networkRuleSet` and Private Endpoint require the **Premium** SKU. If the registry is
Basic/Standard and a PE or IP rule is expected, flag it (the control can't exist there).

## As a target (from AKS / Container Apps / App Service)

The referencing adapter already adds the ACR node; here collect the inbound facts above
and run:

- RF-06 (public disabled + no reachable PE),
- RF-04 on `privatelink.azurecr.io` (and the data-endpoint records),
- RF-09 analog on `networkRuleSet` for the public-with-IP-rules model.

Auth (not network, but masquerades as a network failure): image-pull needs `AcrPull`
on the caller's identity — if RBAC is missing the pull fails even when the network is
open. Note it as ⚪ (out of network scope) when the identity lacks `AcrPull`.

## Facts to emit

```text
FACT target acr1 sku=Premium pna=Disabled bypass=AzureServices pe=[Approved] zoneLinked=true dataEndpoint=true
```
