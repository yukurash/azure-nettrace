# Adapter: API Management (`microsoft.apimanagement/service`)

APIM has two very different VNet modes, and which one is active changes the whole trace.

## VNet mode (the first thing to determine)

`properties.virtualNetworkType`:

| Value | Meaning |
|---|---|
| `None` | Not injected into a VNet. Egress from APIM's public IPs; backends reached over the internet. |
| `External` | Injected into a subnet; gateway still has a public VIP (inbound public, outbound via subnet). |
| `Internal` | Injected; gateway is private only (no public VIP) — inbound via the subnet's private IP. |

Injected subnet: `properties.virtualNetworkConfiguration.subnetResourceId` (→ E3/E4).

## Outbound edges

- Backends are defined in APIM config, not ARM. Enumerate:
  `az apim api list` is not enough — backend hosts live in
  `az rest --method get --url "{id}/backends?api-version=2023-05-01-preview"`
  (host in `properties.url`). Treat each backend host as a Phase-3 target
  (confidence: confirmed — it's an explicit backend).
- Named values may hold backend URLs / secrets: `az apim nv list` — **mask** secret
  named values (they are `secret=true`); only extract host from non-secret URLs.

## Inbound controls

- `Internal` mode → clients must resolve the gateway hostname to the subnet private IP;
  needs a private DNS zone / A record for the custom domain (RF-04-style check).
- `properties.publicIpAddressId` + NSG on the injected subnet must allow the required
  APIM management ports (the subnet NSG is a common breakage — APIM needs specific
  service-tag rules; flag missing ones as 🟡, cite the APIM networking requirements).
- `properties.hostnameConfigurations[]` → custom domains + cert source (KV reference →
  add vault dependency).

## Type-specific red flags

- RF-01 against the injected subnet NSG (APIM requires several outbound allows).
- Backend that is a PE-only Azure resource → full RF-04/06 chain on that backend.

## Facts to emit

```
FACT apim apim1 vnetType=Internal subnet=snet-apim publicVip=none
FACT backend apim1 -> contoso-func.azurewebsites.net (confirmed: backend url)
```
