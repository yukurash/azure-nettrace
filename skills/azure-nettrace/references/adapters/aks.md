# Adapter: AKS (`microsoft.containerservice/managedclusters`)

AKS networking has cluster-wide knobs that change how *every* pod egresses, so the
cluster-level facts matter more than any single NIC.

## Placement / egress edges

| Aspect | Where |
|---|---|
| Node subnet(s) | `properties.agentPoolProfiles[].vnetSubnetID` (per pool; may differ) |
| Pod subnet (Azure CNI overlay/pod-subnet) | `properties.agentPoolProfiles[].podSubnetID` |
| Network plugin | `properties.networkProfile.networkPlugin` (`azure` / `kubenet` / `none`) + `networkPluginMode` |
| **Outbound type** ★ | `properties.networkProfile.outboundType` (`loadBalancer` / `userDefinedRouting` / `managedNATGateway` / `userAssignedNATGateway`) |
| API server access | `properties.apiServerAccessProfile` → `enablePrivateCluster`, `authorizedIpRanges` |

## Why outboundType is the crux (RF-12 variant)

- `userDefinedRouting` → **you** must provide the egress route. The node subnet's
  route table **must** have a `0.0.0.0/0` route (usually → NVA/Azure Firewall).
  If Q5/Q6 show no such route → 🔴 RF-12: cluster has no egress path.
- `loadBalancer` (default) → egress via the cluster LB's public IP; that IP is what a
  target firewall must allow (feeds RF-08).
- NAT gateway variants → egress via the NAT GW public IP.

## Connection settings

Pod-level config (env, mounted secrets) is inside Kubernetes, out of ARM scope.
Infer from:
- The cluster / kubelet **managed identity** and any **workload identity** federated
  credentials → Q11 for role scopes.
- ACR attachment: `properties.` + `az aks show --query "identityProfile"` /
  role assignment `AcrPull` on a registry → add edge cluster→ACR (port 443).

Targets discovered only via K8s manifests: mark ⚪ inferred-from-user.

## Inbound controls

- Private cluster: `enablePrivateCluster=true` → API server has a PE +
  `privatelink.{region}.azmk8s.io` zone; run the DNS chain on it.
- `authorizedIpRanges` present → API server public but IP-restricted (🟡 if empty list
  with private cluster off = open API server).

## Facts to emit

```
FACT aks aks1 outboundType=userDefinedRouting nodeSubnet=snet-aks plugin=azure private=true
FACT egress aks1: rt-aks has 0.0.0.0/0 -> VirtualAppliance 10.10.9.4   (RF-03 + satisfies RF-12)
```
