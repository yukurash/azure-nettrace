# Adapter: Virtual Machine / VM Scale Set

Types: `microsoft.compute/virtualmachines`, `microsoft.compute/virtualmachinescalesets`.

Unlike App Service, a VM's network config lives on its **NIC(s)**, not the compute
resource. The compute body only points at the NIC.

## Outbound / placement edges

| Step | Where |
|---|---|
| VM → NIC(s) | `properties.networkProfile.networkInterfaces[].id` |
| NIC → subnet | `az network nic show` → `ipConfigurations[].subnet.id` (then E3/E4 in walker) |
| NIC → NSG (NIC-level) | `ipConfigurations`' NIC `networkSecurityGroup.id` — **in addition** to the subnet NSG; both apply (most specific allow/deny both evaluated) |
| Public IP | NIC `ipConfigurations[].publicIPAddress.id` — if present, VM can egress/ingress directly, bypassing subnet routing for that path |
| Effective routes/rules (best signal) | `az network nic show-effective-route-table` and `az network nic list-effective-nsg` — these collapse subnet+NIC+default into the real picture; use when available |

For VMSS, network config is under
`properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[]`.

## Connection settings

VMs have no managed appSettings. Infer targets from:
- The VM's **managed identity** (Q11) → data-plane role scopes (Phase 3 source #4).
- If the user names an app on the VM, ask for its config file path (out of ARM scope —
  mark such targets ⚪ inferred-from-user).

## Inbound controls

- NIC-level + subnet-level NSGs (both).
- Public IP present → note it (🟡 if an NSG allows a management port like 22/3389 from `*`/Internet).
- PE pointing at the VM is unusual; Q4 normally empty.

## Type-specific red flags

- RF-01/02 evaluated against the **union** of NIC NSG and subnet NSG. Prefer the
  effective-NSG output when you can read it.
- RF-03 (UDR→NVA) fully applies — VMs commonly egress through a firewall.

## Facts to emit

```
FACT vm vm1 nic=nic1 subnet=snet-app nsgSubnet=nsg-a nsgNic=none publicIp=none
FACT effective-nsg vm1: outbound 1433 -> Allow (rule AllowSql)
```
