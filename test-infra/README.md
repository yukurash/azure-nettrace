# Test environment

A minimal, disposable environment to validate `azure-nettrace` end to end:

- VNet (`10.20.0.0/16`) with an App Service integration subnet (NSG + delegation)
  and a private-endpoint subnet
- **App Service** (B1 Linux, VNet-integrated) with a SQL connection string and a
  Key Vault reference in its config — the connection-inference targets
- **Azure SQL** server + DB (Basic), `publicNetworkAccess=Disabled`, reached via a
  **private endpoint** + **private DNS zone** (with VNet link)
- **Key Vault** (dependency node)

## `breakScenario` — inject a defect to test red flags

| Value | Injected defect | Expected finding |
|---|---|---|
| `none` | healthy baseline | 0 blockers |
| `missingDnsLink` | private DNS zone not linked to the VNet | 🔴 RF-04 |
| `denyNsg` | NSG denies outbound 1433 | 🔴 RF-01 |
| `noPe` | SQL private-only but no private endpoint | 🔴 RF-06 |
| `nvaRoute` | `0.0.0.0/0` → VirtualAppliance (dummy) | 🟡 RF-03 |

## Deploy

```bash
az group create -n rg-nettrace-test -l japaneast
# SQL requires an admin password; pass it at deploy time (never commit it)
az deployment group create -g rg-nettrace-test -f main.bicep \
  -p breakScenario=none -p sqlAdminPassword="$(openssl rand -base64 24)Aa1!"
```

Then, in Claude Code: **"trace the network connectivity of app-nettrace-xxxxx"**.

Re-deploy with a different `breakScenario` to verify each rule.

## Cost & cleanup

Roughly **~$26/month** of resources (B1 App Service, SQL Basic, private endpoint,
private DNS zone) → about **a few tens of yen for a couple of hours** of testing.

**Always delete when done:**

```bash
az group delete -n rg-nettrace-test --yes --no-wait
```

> The `sqlAdminPassword` parameter is `@secure()` and never stored in the template
> or outputs. Do not put it in a committed parameter file.
