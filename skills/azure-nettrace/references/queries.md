# ARG / CLI query library

Execution: prefer the Azure MCP `extension az` tool; otherwise Bash `az`.
ARG queries run as: `az graph query -q "<KQL>" -o json`
(requires `az extension add --name resource-graph`).

Substitute `{placeholders}` before running. Always keep the `project` clause —
it is the context-size guard.

## Q1 — Resolve input (name or ID → resource)

```kusto
resources
| where name =~ '{input}' or id =~ '{input}'
| project id, name, type, kind, resourceGroup, subscriptionId, location
```

## Q2 — Resource body (properties + identity)

```kusto
resources
| where id =~ '{id}'
| project id, type, kind, identity, properties
```

ARG omits/staleness-lags some properties for some types. When a needed field is
missing, fall back to: `az resource show --ids '{id}' -o json`
(role: ARG = discovery/reverse-lookup, `show` = authoritative values).

## Q3 — App Service network fields (extract from Q2 result)

- `properties.virtualNetworkSubnetId` — regional VNet integration subnet
- `properties.outboundIpAddresses`, `properties.possibleOutboundIpAddresses`
- `vnetRouteAllEnabled` lives in the site config, not the site body:
  `az resource show --ids '{id}/config/web' --query "properties.vnetRouteAllEnabled"`

## Q4 — Private endpoints pointing at a resource (reverse lookup) ★

```kusto
resources
| where type =~ 'microsoft.network/privateendpoints'
| mv-expand conn = properties.privateLinkServiceConnections
| where conn.properties.privateLinkServiceId =~ '{targetId}'
| project peId = id, peName = name,
    subnetId = tostring(properties.subnet.id),
    groupIds = conn.properties.groupIds,
    status = tostring(conn.properties.privateLinkServiceConnectionState.status),
    nicIds = properties.networkInterfaces,
    customDns = properties.customDnsConfigs
```

Also check `properties.manualPrivateLinkServiceConnections` the same way when the
first pass returns nothing (cross-tenant / manual approval flow).

## Q5 — Subnet details (NSG / UDR / SE / delegations)

```kusto
resources
| where type =~ 'microsoft.network/virtualnetworks'
| mv-expand sn = properties.subnets
| where tostring(sn.id) =~ '{subnetId}'
| project vnetId = id, vnetName = name,
    prefix = sn.properties.addressPrefix,
    nsgId = tostring(sn.properties.networkSecurityGroup.id),
    routeTableId = tostring(sn.properties.routeTable.id),
    serviceEndpoints = sn.properties.serviceEndpoints,
    delegations = sn.properties.delegations,
    natGw = tostring(sn.properties.natGateway.id),
    peNetworkPolicies = tostring(sn.properties.privateEndpointNetworkPolicies)
```

For VNet-level facts (peerings, custom DNS) project from the same VNet row:
`properties.virtualNetworkPeerings`, `properties.dhcpOptions.dnsServers`.

## Q6 — NSG rules / route table routes

```kusto
resources
| where id =~ '{nsgId}'
| project name, rules = properties.securityRules
```

Extract into facts **only** the rules whose port range ∩ traced ports ≠ ∅ or whose
access = Deny with a broad prefix. Default rules matter for the "no explicit allow"
check but do not need to be listed individually.

```kusto
resources
| where id =~ '{routeTableId}'
| mv-expand r = properties.routes
| project routeName = tostring(r.name),
    prefix = tostring(r.properties.addressPrefix),
    nextHopType = tostring(r.properties.nextHopType),
    nextHopIp = tostring(r.properties.nextHopIpAddress)
```

## Q7 — PE → NIC → private IP

```kusto
resources
| where type =~ 'microsoft.network/networkinterfaces'
| where tostring(properties.privateEndpoint.id) =~ '{peId}'
| mv-expand ipcfg = properties.ipConfigurations
| project nicId = id,
    privateIp = tostring(ipcfg.properties.privateIPAddress),
    fqdns = properties.dnsSettings
```

## Q8 — PE DNS zone groups (NOT in ARG → az CLI)

```
az network private-endpoint dns-zone-group list \
  --endpoint-name '{peName}' -g '{peResourceGroup}' -o json
```

Extract: zone group name → `privateDnsZoneConfigs[].privateDnsZoneId`.

## Q9 — Private DNS zone VNet links ★ (RF-04)

```kusto
resources
| where type =~ 'microsoft.network/privatednszones/virtualnetworklinks'
| where id startswith '{zoneId}'
| project linkId = id,
    linkedVnet = tostring(properties.virtualNetwork.id),
    state = tostring(properties.virtualNetworkLinkState),
    registrationEnabled = properties.registrationEnabled
```

Pass condition: some `linkedVnet` equals the **source** VNet ID.

## Q10 — Target-side firewall (per type, az CLI)

| Target | Commands |
|---|---|
| SQL Server | `az sql server show -n {name} -g {rg} --query "{pna:publicNetworkAccess}"` / `az sql server firewall-rule list -s {name} -g {rg}` / `az sql server vnet-rule list -s {name} -g {rg}` |
| PostgreSQL Flexible | Q2 → `properties.network.{publicNetworkAccess, delegatedSubnetResourceId, privateDnsZoneArmResourceId}` + `az postgres flexible-server firewall-rule list -n {name} -g {rg}` |
| MySQL Flexible | same shape as PostgreSQL (`az mysql flexible-server firewall-rule list`) |
| Storage / Key Vault / Cosmos | Q2 → `properties.publicNetworkAccess`, `properties.networkAcls.{defaultAction, ipRules, virtualNetworkRules, bypass}` |

## Q11 — Managed identity role assignments (inference aid)

```kusto
authorizationresources
| where type =~ 'microsoft.authorization/roleassignments'
| where tostring(properties.principalId) =~ '{principalId}'
| project scope = tostring(properties.scope),
    roleDefinitionId = tostring(properties.roleDefinitionId)
```

Resolve role names only if needed: `az role definition list --custom-role-only false
--query "[?id=='{roleDefinitionId}'].roleName"` (or match well-known data-plane roles
by name via `az role assignment list --assignee {principalId}`).

## Q12 — App configuration (az CLI; output MUST go through masking first)

```
az webapp config appsettings list -n {name} -g {rg} -o json
az webapp config connection-string list -n {name} -g {rg} -o json
az functionapp config appsettings list -n {name} -g {rg} -o json
```

⚠️ Do **not** echo these results. Process them per
`connection-inference.md` (extract host names + key names, mask everything else).
