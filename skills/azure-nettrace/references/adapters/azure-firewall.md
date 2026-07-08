# Adapter: Azure Firewall

Type: `microsoft.network/azurefirewalls` (+ its `microsoft.network/firewallpolicies`).
This is usually the **NVA** at the end of a `0.0.0.0/0` route (RF-03). The whole point
of this adapter is to turn RF-03 from "can't verify the NVA" into a **real verdict**:
does the firewall actually allow the traced flow?

## When it is invoked

- As a **root**: trace what the firewall gates.
- **Automatically from RF-03**: when a traced egress route has
  `nextHopType=VirtualAppliance` and `nextHopIpAddress` matches an Azure Firewall
  private IP (`properties.ipConfigurations[].properties.privateIPAddress`), load this
  adapter and evaluate the rules against the traced flow instead of stopping at 🟡.

## What to read

| Aspect | Where |
|---|---|
| Firewall private IP(s) | `properties.ipConfigurations[].properties.privateIPAddress` (match against UDR next hops) |
| Policy | `properties.firewallPolicy.id` → `az network firewall policy show` (classic rules live inline on the firewall instead) |
| Rule collection groups | `az network firewall policy rule-collection-group list --policy-name {p} -g {rg}` |
| DNS / proxy | policy `dnsSettings` (`enableProxy`) — FQDN application rules only work with the DNS proxy / correct resolution |

## Evaluating the traced flow

Given source IP/subnet, destination (IP or FQDN), and port from the walk, evaluate in
Azure Firewall precedence order:

1. **DNAT rules** — only relevant for inbound; usually skip for egress traces.
2. **Network rules** — match source addr/subnet, destination addr/**service tag**/IP,
   protocol+port. A match with `action=Allow` → ✅ path open at the firewall.
3. **Application rules** — match source + destination **FQDN** (or FQDN tag) for
   HTTP/HTTPS/MSSQL. Needed when the destination is an FQDN (e.g. Storage, SQL) rather
   than an IP. Requires DNS resolution to line up.

Within a rule-collection group, collections are ordered by `priority`; the first
matching **Deny** wins over a later Allow. Report the deciding rule.

## Red flags (this is the RF-03 upgrade)

- 🔴 **No matching Allow** for the traced destination+port across network and application
  rules → the firewall drops the flow. Name the closest collection and why it missed
  (wrong port / destination / FQDN-vs-IP / DNS proxy off).
- 🔴 An explicit **Deny** collection matches first.
- 🟡 Destination is an FQDN but only **network** rules exist (no application rule) and the
  firewall has no way to learn the IP → likely dropped; verify DNS proxy.
- ✅ A network or application rule clearly allows source→dest:port → RF-03 resolves to
  pass (the NVA permits the flow).

## Facts to emit

```text
FACT fw fw1 privateIp=10.20.9.4 policy=afwp-contoso dnsProxy=on
FACT fwEval fw1: snet-appsvc -> contoso-sql.database.windows.net:1433
  -> application rule 'AllowSql' (MSSQL) Allow  => RF-03 PASS
```
