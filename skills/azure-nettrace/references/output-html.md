# HTML report output

The default, most readable output: a **self-contained HTML file** the user opens in a
browser. Nicer than the Mermaid/Markdown form — a left-to-right path diagram with Azure
category icons, severity-striped node cards, a red-flag panel, and dependency tables.
Light/dark aware, no external JS/CSS/fonts.

Use this when the user wants a diagram / a shareable report / "open in browser".
Fall back to `output-format.md` (Markdown + Mermaid) only when the user explicitly wants
inline/terminal output.

## Parameters

- **`lang`**: `ja` | `en` (ask if unset; default `en`). Localizes all labels and the
  narrative; resource names / identifiers stay verbatim.
- **`format`**: `html` (default) | `markdown`.
- **`iconStyle`**: `builtin` (default) | `official` (see § Official icon mode).

## How to build the file

1. Copy the entire `<style>` block **and** the `<svg id="nt-sprite">` sprite from
   `assets/report-template.html` **verbatim** into the output.
2. Set `<title>` and build the `<body>` in this order (same structure as the template):
   1. **header** — `.kicker`, `<h1>` = resource name (monospace), `.sub` (type chip +
      "…network reachability"), `.meta` (subscription truncated · date · read-only).
   2. **`.verdict`** — the answer first. One plain-language sentence stating whether the
      resource can reach its target and, if not, the single root cause. Class = worst
      severity (`verdict crit` / `warn` / `pass`); glyph 🔴/🟡/🟢; a `.counts` line.
   3. **Path** (`<h2>` + `.diagram > .path`) — the schematic (see below).
   4. **Red flags** (`<h2>` + `.flags`) — one `.flag` block per 🔴/🟡 (fcode + title +
      `<dl>` of 根拠/影響/修正 with the fix in `<pre>`), then a `.passline` for ✅, then
      an unverified list for ⚪.
   5. **Dependencies** (`<h2>` + `.tbl > table`) — hop rows with confidence & evidence.
   6. **footer** — masking notice + icon attribution.
3. After the diagram, emit the `<div id="inspector" hidden>` panel, and near the end of
   `<body>` the `<div id="nt-details" hidden>` store and the `<script>` — all three
   **verbatim** from `assets/report-template.html` (only the detail blocks inside the
   store change). See § Interactivity.
4. Write the file to `out/trace-<resource>-<lang>.html` (the `out/` dir is gitignored —
   never commit real trace output). Tell the user the path and that opening it in a
   browser renders the diagram.

The file is plain HTML — it renders by double-clicking. Do not add external `<script>`
or `<link>`; keep it self-contained (an inline `<script>` is fine).

## Interactivity (click to inspect)

Every node **and** branch is clickable: clicking it shows that resource's network
settings in the `#inspector` panel below the diagram. This is what makes the report a
verification tool — press the NSG to read its rules, the SQL server to see its firewall,
the DNS zone to see its VNet links, etc.

Wiring (all provided verbatim in the template — copy, don't re-invent):

1. Make each `.node` / `.branch` interactive: `data-detail="<key>" role="button"
   tabindex="0" aria-expanded="false"` (the CSS already gives hover/focus/selected cues
   and a dotted underline on the name).
2. Put one block per key inside `#nt-details`:
   ```html
   <div data-for="nsg1">
     <div class="dh"><span class="dic"><svg><use href="#nt-nsg"/></svg></span>
       <b>nsg-appsvc</b><span class="dty">NSG · security rules</span></div>
     <!-- .dkv key/value grid, or .dtbl table -->
   </div>
   ```
   Use `.dkv` (a key/value grid) for settings and `.dtbl` (a table) for rule lists.
3. The `<script>` toggles the matching block into the inspector on click / Enter / Space,
   Esc closes, and only one is open at a time. Keep it verbatim.

What to show per resource (network-relevant only; **mask secrets**):

| Resource | Inspector content |
|---|---|
| App Service / Functions | VNet-integration subnet, `vnetRouteAllEnabled`, outbound IPs, access restrictions, `publicNetworkAccess`, PE |
| Subnet | address prefix, NSG, route table, delegations, service endpoints |
| **NSG** | `.dtbl` of security rules: priority, name, direction, access, protocol, ports, source, destination |
| Route table | `.dtbl` of routes: prefix, next-hop type, next-hop IP |
| Private Endpoint | private IP, connection state, `groupId`, subnet, DNS zone group |
| Private DNS zone | VNet links (linked VNet + state), relevant A records, auto-registration |
| SQL / PG / MySQL | `publicNetworkAccess`, firewall rules, VNet rules, PE, min TLS |
| Storage / Key Vault / Cosmos | `publicNetworkAccess`, `networkAcls` (defaultAction/ipRules/vnetRules/bypass), PE, RBAC |
| Azure Firewall | rule collections that matched the traced flow (the deciding allow/deny) |
| others | the same generic facts the fallback collected (public access, networkAcls, PE) |

Highlight a value that is the root cause in red (`<b style="color:var(--crit)">…</b>`).

## Path schematic

The path is a horizontal wired diagram, **not** boxed cards. Each hop is a `.node`
(icon + name + type); hops are joined by `.link` connectors that carry a label:

```html
<div class="path">
  <div class="node">
    <span class="ic" style="--catcolor:var(--cat-web)"><svg><use href="#nt-appservice"/></svg></span>
    <span class="nm">contoso-app</span><span class="ty">App Service</span>
    <!-- optional side dependency hanging below this node: -->
    <div class="branch" style="--bcat:var(--cat-sec)"><span class="drop"></span>
      <span class="bic"><svg><use href="#nt-keyvault"/></svg></span>
      <span class="bn">contoso-kv</span><span class="bnote">KV ref</span></div>
  </div>
  <div class="link"><div class="line"></div><span class="lab">VNet integration</span></div>
  <!-- … more nodes/links … -->
  <div class="node">… <span class="mk crit">unreachable</span></div>
</div>
```

- **Main line** = the source → target chain. Put branch/side resources (Key Vault,
  DNS zone, NSG) as a `.branch` **under** the node they belong to (a drop connector +
  small icon + note), so the layout stays aligned without cross-column math.
- A **broken hop** uses `<div class="link broken">` (adds a red dashed line, arrowhead
  and a `✕`); its `.lab` states why (e.g. "DNS unresolved → public IP").
- Mark an unreachable/at-risk node with `<span class="mk crit">…</span>` (or `mk ok`).

## Node icons — type → sprite key

Set the node's category color with `style="--catcolor:var(--cat-…)"` and reference the
symbol with `<use href="#nt-…"/>`. (In official-icon mode, replace the `<use>` with the
inlined official SVG — see below.)

| Resource | sprite key `#nt-…` | `--cat-…` |
|---|---|---|
| App Service / Functions / Static Web Apps | `appservice` (`function` for functions) | `web` |
| Container Apps | `containerapp` | `web` |
| VM / VMSS | `vm` | `compute` |
| AKS | `aks` | `compute` |
| SQL / PostgreSQL / MySQL | `sql` | `data` |
| Storage | `storage` | `data` |
| Cosmos DB | `cosmos` | `data` |
| Key Vault | `keyvault` | `sec` |
| Redis | `redis` | `data` |
| Service Bus / Event Hubs / Event Grid | `messaging` | `integration` |
| Container Registry | `acr` | `web` |
| AI Search | `search` | `ai` |
| Foundry (CogSvc / ML / OpenAI) | `foundry` | `ai` |
| VNet | `vnet` | `net` |
| Subnet | `subnet` | `net` |
| NSG | `nsg` | `net` |
| Route table | `routetable` | `net` |
| Private Endpoint | `pe` | `net` |
| Private DNS zone | `dns` | `dns` |
| Azure Firewall | `firewall` | `net` |
| Application Gateway | `appgateway` | `net` |
| Front Door / CDN | `frontdoor` | `net` |
| Load Balancer | `lb` | `net` |
| anything else | `generic` | `net` |

## Severity → classes

| Verdict | verdict band | node mark | broken hop | red-flag block |
|---|---|---|---|---|
| blocker 🔴 | `verdict crit` (glyph 🔴) | `mk crit` | `link broken` on the failing hop | `flag` (red `fcode`) |
| warning 🟡 | `verdict warn` (glyph 🟡) | `mk warn` | — | `flag warn` |
| pass ✅ | `verdict pass` (glyph 🟢) | `mk ok` | — | one `passline` summarizing passes |
| unverified ⚪ | — | — | — | a short list under the flags |

The overall `.verdict` band takes the **worst** severity present. A `.branch` that is
the root cause (e.g. an unlinked DNS zone) gets `branch crit`.

## Label dictionary

Use the column for `lang`. Left = key.

| key | en | ja |
|---|---|---|
| eyebrow | connectivity trace | 接続性トレース |
| title | Network reachability of {name} | {name} のネットワーク到達性 |
| type | Type | 種別 |
| subscription | Subscription | サブスクリプション |
| generated | Generated | 生成 |
| readonly | read-only trace | 読み取り専用トレース |
| maskNotice | Secrets in configuration values are masked. This output still contains resource names and private IPs — handle accordingly. | 構成値のシークレットはマスク済みです。この出力にはリソース名とプライベートIPが含まれます。取り扱いに注意してください。 |
| blockers | Blockers | ブロッカー |
| warnings | Warnings | 警告 |
| passed | Passed | 合格 |
| unverified | Unverified | 未確認 |
| secPath | Path | 経路 |
| pathHint | source → target, left to right | 左から右へ、送信元から接続先まで |
| tierSource | Source | ソース |
| tierEgress | Egress | 送信経路 |
| tierPrivate | Private link | プライベート接続 |
| tierTarget | Target | 接続先 |
| tierControls | Target controls | 接続先の制御 |
| secFlags | Red flags | 赤信号 |
| flagsHint | most severe first | 重大度順 |
| passedAll | passed | 合格 |
| noBlockers | no reachability blockers found. | 到達性のブロッカーは見つかりませんでした。 |
| facts | facts | 根拠 |
| effect | effect | 影響 |
| fix | fix | 修正 |
| secDeps | Dependencies | 依存関係 |
| depsHint | hop by hop, with confidence & evidence | ホップごと・確度と根拠つき |
| colHop | Hop | ホップ |
| colResource | Resource | リソース |
| colType | Type | 種別 |
| colFacts | Key facts | 主要な事実 |
| colConf | Confidence | 確度 |
| colEvidence | Evidence | 根拠 |
| confConfirmed | confirmed | 確認済 |
| confInferred | inferred | 推定 |
| confCorroborating | corroborating | 傍証 |
| reachable | Reachable | 到達可 |
| unreachable | unreachable | 到達不可 |
| verdictReach | Reachable | 到達可 |
| verdictBlocked | unreachable | 到達不可 |
| kvref | KV ref | KV参照 |
| clickHint | Click a node to inspect that resource's network settings. | ノードをクリックすると、そのリソースのネットワーク設定を確認できます。 |
| close | Close | 閉じる |
| netSettings | network settings | ネットワーク設定 |
| secRules | security rules | セキュリティ規則 |
| footerBuiltin | Secrets masked. Icons: azure-nettrace built-in set. | シークレットはマスク済み。アイコンは azure-nettrace 内蔵セット。 |
| footerOfficial | Secrets masked. Icons: Microsoft Azure official architecture icons. | シークレットはマスク済み。アイコン: Microsoft Azure 公式アーキテクチャアイコン。 |

Red-flag titles/effects/fixes: write them in `lang`. Keep the `RF-NN` code and any
`az …` command verbatim (commands are language-neutral).

## Official icon mode (`iconStyle: official`)

The built-in sprite is license-safe and ships with the repo. Microsoft's **official**
Azure architecture icons may **not** be redistributed as a standalone set, so they are
not committed here — but you may embed them **into a generated diagram** (the permitted
use). To enable:

1. One-time: download the official set from
   <https://learn.microsoft.com/azure/architecture/icons/> ("Download SVG icons" →
   `Azure_Public_Service_Icons_V*.zip`) and unzip it under `assets/azure-icons/` (this
   path is gitignored — never commit it). The manifest's `_officialRoot`
   (`assets/azure-icons/Azure_Public_Service_Icons/Icons/`) is where the SVGs live.
2. `assets/azure-icon-manifest.json` maps each resource `type` → `{builtin, official}`,
   where `official` is the SVG path relative to `_officialRoot`. For each node, read the
   mapped SVG and **inline it** in place of `<svg><use href="#nt-…"/></svg>`: keep its
   `viewBox`, strip the root `width`/`height` so CSS sizes it. The official icons carry
   their own brand colors — do **not** apply `--catcolor` to them.
3. If a mapping/file is missing, fall back to the built-in `#nt-…` symbol for that node.
4. Set the footer to `footerOfficial`.

Terms: Microsoft permits these icons in architecture diagrams/documentation — embedding
them in a generated report is fine; redistributing the set as files is not (hence the
gitignore).

Never commit `assets/azure-icons/` or any official SVG. The built-in set stays the
default so the skill works out of the box.
