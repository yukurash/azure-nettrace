# Red-flag rule catalog (v1: RF-01 … RF-12)

Evaluate every rule against the facts list in Phase 5. Verdicts:
🔴 blocker (connection very likely broken) / 🟡 warning (verify) /
✅ pass / ⚪ unverified (state the reason: permission, missing data, custom DNS...).

Port expectations come from the port map in `walker.md`.

---

## RF-01 🔴 — NSG blocks required outbound port
**Where:** NSG on the source's egress subnet.
**Condition:** a `securityRules[]` entry with `direction=Outbound, access=Deny` whose
port range covers the target port and whose `destinationAddressPrefix` covers the
target (specific prefix, `*`, `Internet`, or the matching service tag), **and** no
`Allow` rule with a lower `priority` number overrides it.
**Report:** rule name, priority, port, destination prefix.

## RF-02 🔴 — NSG on the PE subnet blocks inbound
**Where:** NSG on the subnet hosting the target's private endpoint.
**Condition:** subnet `privateEndpointNetworkPolicies == 'Enabled'` (or
`'NetworkSecurityGroupEnabled'`) **and** an `Inbound Deny` rule covers the target port
from the source's address space, with no lower-priority Allow.
**Note:** if network policies are `Disabled`, NSG rules do not apply to the PE → ✅.

## RF-03 🟡→🔴/✅ — Default route points to an NVA
**Where:** route table on the source's egress subnet.
**Condition:** a route with `addressPrefix == '0.0.0.0/0'` and
`nextHopType == 'VirtualAppliance'`.
**Upgrade path:** if `{nextHopIp}` matches an **Azure Firewall** private IP, load
`adapters/azure-firewall.md` and evaluate its rule collections against the traced
`source → {target}:{port}` flow. This turns the finding into a real verdict:
🔴 if no rule allows it (name the missing/blocking collection), ✅ if a network or
application rule allows it. Only fall back to 🟡 when the NVA is a third-party
appliance whose policy is not in ARM.
**Report (unresolved case):** "egress traverses NVA at {nextHopIp}; policy not in ARM —
confirm it allows {target}:{port}."

## RF-04 🔴 — Private DNS zone lacks a link to the source VNet
**Where:** the `privatelink.*` zone matching the target service (zone map in `walker.md`).
**Condition:** target is reached via PE (or is PE-only per RF-06 facts), the matching
zone exists, but Q9 shows **no** VNet link whose `linkedVnet` equals the source VNet.
**Effect:** the FQDN resolves to the public IP → connection bypasses the PE and is
then subject to the target's public firewall (often Deny).
**Note:** if the source VNet uses custom DNS servers → downgrade to ⚪ with the DNS
server IPs listed.

## RF-05 🟡 — PE without a DNS zone group
**Where:** each PE on the traced path.
**Condition:** Q8 returns no zone group **and** no matching A record can be confirmed
in the corresponding zone.
**Effect:** DNS records are not managed automatically; resolution may be stale/absent.

## RF-06 🔴 — Public access disabled but no private path
**Where:** target resource.
**Condition:** `publicNetworkAccess == 'Disabled'` and Q4 (against the target) returns
no `Approved` PE reachable from the source VNet (same VNet, or peered VNet with the
DNS chain intact).

## RF-07 🔴 — Private endpoint connection not approved
**Where:** each PE on the traced path.
**Condition:** `privateLinkServiceConnectionState.status` ∈ {`Pending`, `Rejected`, `Disconnected`}.

## RF-08 🔴 — Target firewall does not admit the source
**Where:** SQL / PostgreSQL / MySQL-style firewalls (Q10).
**Condition (all must fail):**
- no firewall rule range `startIpAddress–endIpAddress` covering any source outbound IP, and
- no VNet rule whose `virtualNetworkSubnetId` equals the source's egress subnet, and
- no usable PE path (per RF-04/06/07 facts).
**Special case 🟡:** a `0.0.0.0–0.0.0.0` rule ("Allow Azure services") technically
admits the app but is over-broad — report as 🟡 even when it makes the connection work.

## RF-09 🔴 — networkAcls deny with no admitted path
**Where:** Storage / Key Vault / Cosmos (`properties.networkAcls`).
**Condition:** `defaultAction == 'Deny'` and none of: source subnet in
`virtualNetworkRules[]`, source outbound IP in `ipRules[]`, usable PE path.
**Note:** check `bypass` (e.g. `AzureServices`) before concluding — report what applies.

## RF-10 🔴 — Service endpoint missing for a VNet rule
**Where:** pair = target VNet rule ↔ source subnet.
**Condition:** the target has a VNet rule for the source subnet, but Q5 shows the
subnet's `serviceEndpoints[]` lacks the matching service
(`Microsoft.Sql` / `Microsoft.Storage` / `Microsoft.KeyVault` / `Microsoft.AzureCosmosDB`).
**Effect:** the VNet rule never matches; traffic arrives from a public IP instead.

## RF-11 🟡 — Route-all disabled while target is private-only
**Where:** App Service with VNet integration.
**Condition:** `vnetRouteAllEnabled == false` (and no `WEBSITE_VNET_ROUTE_ALL=1`),
and a traced target is PE-only (public access disabled).
**Effect:** traffic to the target's **public FQDN** leaves via public IPs and gets
denied; only RFC1918 traffic enters the VNet. (With a correct private-DNS chain the
FQDN resolves to a private IP and traffic does enter the VNet — hence 🟡, not 🔴:
verify the DNS chain first.)

## RF-12 🔴 — Subnet delegation / egress-type mismatch
**Where:** source egress subnet.
**Conditions (variants):**
- App Service integration subnet not delegated to `Microsoft.Web/serverFarms`
- AKS with `outboundType == 'userDefinedRouting'` but the node subnet's route table
  has no `0.0.0.0/0` route
- Flexible-server delegated subnet used by a different service's delegation

---

## Reporting format (per rule)

```
RF-04 🔴 privatelink.database.windows.net not linked to vnet-contoso-prod
  facts: zone exists (3 links) — none match source VNet id
  effect: contoso-sql.database.windows.net resolves to public IP from this VNet
  fix: az network private-dns link vnet create ... (one-liner suggestion)
```

Every 🔴/🟡 must cite the facts it used. Rules whose inputs were unreadable are ⚪,
never silently skipped.
