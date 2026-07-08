# Adapter: Front Door / CDN

Type: `microsoft.cdn/profiles` (Front Door Standard/Premium and CDN). A **global** L7
entry point — no VNet/subnet of its own; reachability to origins is the interesting part.

## Structure

| Aspect | Where (sub-resources under the profile) |
|---|---|
| Endpoints | `az afd endpoint list --profile-name {p} -g {rg}` — the public hostnames |
| Origin groups | `az afd origin-group list ...` — health-probe + load-balancing settings |
| Origins | `az afd origin list --origin-group {og} ...` — each has `hostName` (the backend), `enabledState`, and optionally `sharedPrivateLinkResource` |
| WAF / security policy | `az afd security-policy list ...` → linked WAF policy; a blocking rule looks like an origin outage (🟡) |

## Private Link origins (Premium — the key reachability case)

Front Door **Premium** can reach a private origin (App Service / Storage / internal ALB /
App Gateway) over Private Link instead of the public internet:

- origin `sharedPrivateLinkResource.privateLink` → the target resource ID
- the target must **approve** the Front Door private endpoint connection — check
  `privateLinkServiceConnectionState.status` on the target (Q4). `Pending`/`Rejected`
  → 🔴 (origin unreachable via Private Link).
- Standard SKU has **no** Private Link — a private-only origin is unreachable from a
  Standard profile (🔴, note the SKU).

## Origin reachability

For a **public** origin: the origin's own firewall must allow Front Door — either via
the `AzureFrontDoor.Backend` service tag or by validating the `X-Azure-FDID` header.
If the origin is a locked-down App Service / Storage with `defaultAction=Deny` and no
Front Door service-tag/PE path → 🔴 (RF-08/RF-09 analog, evaluated against Front Door,
not a VNet).

## Red flags

- Private Link origin `Pending`/`Rejected` (RF-07 analog).
- Standard SKU + private-only origin (unreachable by design).
- Public origin firewall does not admit `AzureFrontDoor.Backend` / FDID (RF-08/09 analog).

## Facts to emit

```text
FACT afd fd1 sku=Premium endpoints=[contoso.z01.azurefd.net]
FACT origin fd1 -> contoso-app.azurewebsites.net privateLink=Approved
FACT origin fd1 -> contoso-st.blob.core.windows.net publicOrigin fwAdmitsFrontDoor=false  (RF-08 analog)
```
