# Adapter: Container Apps

Two resource types, and the networking lives on the **environment**, not the app:

- `microsoft.app/managedenvironments` — the Container Apps environment (VNet, ingress model)
- `microsoft.app/containerapps` — an individual app (ingress, registries, env/secrets)

When the trace root is a container app, always pull its environment
(`properties.managedEnvironmentId`) — that is where subnet integration is decided.

## Managed environment (`microsoft.app/managedenvironments`)

| Aspect | Where |
|---|---|
| VNet integration subnet | `properties.vnetConfiguration.infrastructureSubnetId` (null = not VNet-injected) |
| Internal vs external | `properties.vnetConfiguration.internal` (`true` = no public inbound; ingress uses the internal load balancer) |
| Static / outbound IPs | `properties.staticIp`, plus `az containerapp env show` for outbound IPs used when egress does not go through the subnet |
| Reserved CIDRs | `properties.vnetConfiguration.{platformReservedCidr, dockerBridgeCidr}` — overlaps with peered ranges break connectivity (🟡) |
| Workload profiles | `properties.workloadProfiles[]` — Consumption-only vs dedicated; private endpoints to the environment require a workload-profile environment |
| Private endpoints (to the env) | Q4 on the environment ID (workload-profile envs). The env domain is `properties.defaultDomain` (e.g. `<name>.<region>.azurecontainerapps.io`) |

Subnet requirements (RF-12 variants): the infrastructure subnet must be delegated
appropriately for the environment type and be large enough (`/23` for classic
Consumption). Read the subnet via Q5 and note delegation / size mismatches.

### Internal environment DNS (RF-04 analog)

When `internal == true`, the environment's default domain resolves to the internal
load balancer's private IP via a **private DNS zone** named after `defaultDomain`.
A caller in another VNet needs that zone **linked** to reach the app; run the Q9
VNet-link check against the environment's private DNS zone.

## Container app (`microsoft.app/containerapps`)

| Aspect | Where |
|---|---|
| Environment | `properties.managedEnvironmentId` (→ pull the environment, above) |
| Ingress | `properties.configuration.ingress.{external, targetPort, transport}` + `ipSecurityRestrictions[]` |
| Registries | `properties.configuration.registries[]` → ACR dependency (port 443); check the ACR's own networkAcls |
| Secrets | `properties.configuration.secrets` — **names only** via `az containerapp secret list` (values are write-only; never print) |
| Env vars (inference) | `properties.template.containers[].env[]` — `value` or `secretRef`; scan values for FQDNs / connection strings per `connection-inference.md` (mask secrets) |
| Dapr | `properties.configuration.dapr` — Dapr components may bind Storage / Service Bus / state stores; list via `az containerapp env dapr-component list` |
| Identity | `identity.principalId` (+ user-assigned) → Q11 |

## Type-specific red flags

- RF-01/02 against the **infrastructure subnet** NSG (Container Apps requires specific
  outbound allows; a blanket deny breaks the platform).
- RF-03 (UDR → NVA) applies; with `AllowOnlyApprovedOutbound`-style firewalls the NVA
  must allow the platform + target FQDNs.
- RF-04 analog on the internal environment's private DNS zone (above).
- Internal env (`internal=true`) but a caller expects the public FQDN → the public name
  will not resolve to a reachable address (🟡, note the internal-only ingress).

## Facts to emit

```text
FACT env env1 internal=true infraSubnet=snet-aca staticIp=10.30.0.10 profiles=[Consumption]
FACT app app1 env=env1 ingress=internal:8080 registries=[contoso-acr] 
FACT inference app1 -> contoso-sql.database.windows.net (confirmed: env[SQL_CONN])
FACT dns env1 zone=<defaultDomain> linkedToCaller=false   (RF-04 analog)
```
