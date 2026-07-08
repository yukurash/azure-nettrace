# Adapter: Service Bus / Event Hubs

Types: `microsoft.servicebus/namespaces`, `microsoft.eventhub/namespaces`
(Relay `microsoft.relay/namespaces` follows the same shape). Usually **targets**;
port 5671 (AMQP-TLS) or 443 (AMQP-over-WebSockets).

## The key gotcha: `networkRuleSet`, not `networkAcls`

These namespaces express inbound network rules under a **different** name and often a
**sub-resource**, which the generic fallback misses:

- `properties.publicNetworkAccess` (`Enabled` / `Disabled` / `SecuredByPerimeter`)
- Network rule set:
  `az servicebus namespace network-rule-set list --namespace-name {ns} -g {rg}`
  (Event Hubs: `az eventhubs namespace network-rule-set list`) →
  `defaultAction`, `ipRules[]`, `virtualNetworkRules[].subnet.id`
- `trustedServiceAccessEnabled` — analogous to a bypass; evaluate before concluding a block

## Private endpoints

Q4 on the namespace ID; zone `privatelink.servicebus.windows.net`
(Event Hubs shares this zone; Relay uses `privatelink.servicebus.windows.net` too).
Standard/Premium differences: PE requires **Premium** for Service Bus — if the namespace
is Standard and a PE is expected, note it (the PE cannot exist).

## Red flags

- RF-09 analog on `networkRuleSet` (`defaultAction=Deny` and source subnet not in
  `virtualNetworkRules`, source IP not in `ipRules`, no PE) — 🔴.
- RF-10 (VNet rule present but the source subnet lacks the `Microsoft.ServiceBus` /
  `Microsoft.EventHub` service endpoint) — 🔴.
- RF-06 (public disabled + no reachable PE), RF-04 (zone not linked), RF-01 (NSG denies
  5671 outbound).

## Facts to emit

```text
FACT target sb1 pna=Disabled ruleSet.default=Deny vnetRules=[snet-app] pe=[Approved] zoneLinked=true
FACT target eh1 pna=Enabled ruleSet.default=Allow trustedServiceAccess=true
```
