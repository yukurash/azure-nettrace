# Adapter: Application Gateway

Type: `microsoft.network/applicationgateways`. A regional L7 reverse proxy that fronts
App Services / AKS / VMs. Rich, commonly-misconfigured networking — useful as a root
(inbound path) and as an intermediate hop.

## Placement / edges

| Aspect | Where |
|---|---|
| Dedicated subnet | `properties.gatewayIPConfigurations[].subnet.id` — App Gateway must have its **own** subnet; run Q5/Q6 on it |
| Frontend IPs | `properties.frontendIPConfigurations[]` — public IP and/or a private IP (internal ILB); note which |
| Backend pools | `properties.backendAddressPools[].backendAddresses[]` — FQDNs / IPs of the real targets → each backend is a downstream node; route FQDNs through `connection-inference.md` |
| HTTP settings | `properties.backendHttpSettingsCollection[]` — port, protocol (HTTPS → the backend must present a cert), `pickHostNameFromBackendAddress`, probe |
| WAF | `properties.webApplicationFirewallConfiguration` or a linked `firewallPolicy` (`properties.firewallPolicy.id`) — a blocking WAF rule can look like a backend outage (🟡) |

## Subnet NSG requirements (RF-01 variant)

App Gateway v2 requires specific inbound allows on its subnet NSG or it breaks:
- inbound TCP **65200-65535** from the `GatewayManager` service tag (control plane) — if
  denied, the gateway is unhealthy → 🔴
- inbound from `AzureLoadBalancer`
- inbound on the listener ports (80/443) from the expected sources

Read the subnet NSG (Q6) and check these explicitly.

## Backend reachability (the common failure)

For each backend, the gateway → backend path is a *separate* trace: the gateway's subnet
must reach the backend, and the backend's own firewall/NSG/PE must admit the gateway's
subnet (not the original client). When the backend is a private App Service or a
PE-only resource, run the full RF-04/06/08 chain **from the gateway subnet**.

## Red flags

- RF-01 variant: missing GatewayManager 65200-65535 inbound allow → gateway unhealthy.
- Backend chain: RF-06/RF-08/RF-04 evaluated from the gateway subnet to each backend.
- HTTPS backend with hostname/cert mismatch (`pickHostNameFromBackendAddress=false` and
  no `hostName`) → probe fails (🟡, note as config not pure network).

## Facts to emit

```text
FACT appgw agw1 subnet=snet-agw frontend=[public 20.x, private 10.40.0.10] wafMode=Prevention
FACT nsgCheck agw1 subnet: GatewayManager 65200-65535 inbound = Allow (OK)
FACT backend agw1 -> contoso-app.azurewebsites.net (private) : run RF chain from snet-agw
```
