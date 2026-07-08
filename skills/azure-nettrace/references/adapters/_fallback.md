# Adapter: fallback for unknown / uncovered resource types

Used when no specific adapter matches the resource `type`. Goal: still produce a useful
trace using only type-independent reasoning, so the skill degrades gracefully instead
of failing.

## Procedure

1. **Full body**: `az resource show --ids '{id}' -o json` (ARG Q2 may lag/omit fields).
2. **Regex-scan `properties` for network references:**
   - Subnet references: any string matching `/subnets/` → candidate egress/placement
     subnet → run E3/E4 (walker).
   - Resource-ID references: `/subscriptions/.../providers/...` → candidate dependency
     nodes (resolve type via the ID; add as edges with confidence: inferred).
   - FQDNs: match against the suffix table in `connection-inference.md` → candidate
     outbound targets.
3. **Generic inbound properties** (check each if present):
   - `publicNetworkAccess`
   - `networkAcls` (defaultAction / ipRules / virtualNetworkRules)
   - `privateEndpointConnections` (inline) — and always run Q4 against the resource ID
   - `networkRuleSet` (some services use this name instead of networkAcls)
4. **Identity**: if `identity.principalId` present → Q11 for role-based inference.
5. **Private endpoints**: Q4 reverse lookup regardless of type; if any, run the PE→NIC→
   DNS chain (E6/E7/E8) and the relevant RF rules.

## Applicable red flags

RF-01/02/03 (if a subnet was found), RF-04/05/06/07 (if PEs were found),
RF-09 (if networkAcls present), RF-10 (if a VNet rule + subnet pair exists).
Rules whose inputs are absent → not applicable (state so briefly, not ⚪).

## Output caveat

Add a one-line note to the artifact:

> ⚠️ No specialized adapter for `{type}`; trace used generic reasoning. Some
> service-specific network controls may not be covered — treat ✅ results as
> "no generic blocker found", not a guarantee.

## When to suggest adding an adapter

If a fallback trace hits a resource whose `properties` clearly has service-specific
network config the generic scan can't interpret, note it — that's a signal a dedicated
adapter file would help (candidate for a future PR).
