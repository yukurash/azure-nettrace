# Connectivity trace: contoso-app (App Service)

> 🔒 Secrets in configuration values are masked. This output still contains
> resource names and private IPs — handle accordingly.
> Generated 2026-07-08 · subscription: 00000000… · read-only trace

> _Sanitized example. Generated from a live trace of the `test-infra` environment
> with `breakScenario=missingDnsLink` (the private DNS zone's VNet link removed)._

## Diagram

```mermaid
flowchart LR
  classDef red stroke:#d33,stroke-width:3px
  classDef warn stroke:#e6a700,stroke-width:3px
  classDef unknown stroke-dasharray: 5 5

  subgraph vnet1["contoso-vnet (10.20.0.0/16)"]
    subgraph snet1["snet-appsvc (10.20.1.0/24)"]
      app1["contoso-app<br/>App Service"]
    end
    subgraph snet2["snet-pe (10.20.2.0/24)"]
      pe1["pe-sql<br/>Private Endpoint 10.20.2.4"]
    end
  end
  sql1["contoso-sql<br/>SQL Server (PNA disabled)"]:::red
  dns1["privatelink.database.windows.net<br/>Private DNS zone (NOT linked)"]:::red

  app1 -->|"vnet integration"| snet1
  app1 -->|"inferred: connectionStrings[AppDb]"| sql1
  pe1 -->|"private link (Approved)"| sql1
  dns1 -. "no VNet link → resolves to public IP" .-> vnet1
```

## Dependencies

| # | Hop | Resource | Type | Key facts | Confidence | Evidence |
|---|-----|----------|------|-----------|------------|----------|
| 1 | source | contoso-app | App Service | vnetRouteAll=true | — | — |
| 2 | egress subnet | snet-appsvc | Subnet | NSG=nsg-appsvc, deleg=Microsoft.Web/serverFarms | — | — |
| 3 | target | contoso-sql | SQL Server | PNA=Disabled, PE=Approved@snet-pe | confirmed | connectionStrings["AppDb"] |
| 4 | dns | privatelink.database.windows.net | Private DNS zone | **0 VNet links to source VNet** | — | — |

## Red flags

### 🔴 RF-04 — privatelink.database.windows.net is not linked to contoso-vnet
- **facts**: the zone exists and the private endpoint has a DNS zone group, but the
  zone has **no VNet link** to the source VNet (contoso-vnet)
- **effect**: `contoso-sql.database.windows.net` resolves to its **public** IP from this
  VNet; with `publicNetworkAccess=Disabled` the connection is refused — even though the
  private endpoint itself is healthy and Approved
- **fix**:
  ```bash
  az network private-dns link vnet create -g <rg> \
    -z privatelink.database.windows.net -n link-contoso \
    --virtual-network <vnetId> --registration-enabled false
  ```

✅ passed: RF-01, RF-02, RF-03, RF-05, RF-06, RF-07, RF-08, RF-09, RF-10, RF-11, RF-12

> This is the classic "private endpoint is set up but it still can't connect" case —
> the endpoint is fine; DNS is the missing link.
