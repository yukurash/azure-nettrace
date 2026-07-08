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
2. Set `<title>` and build the `<body>` with the same structure as the template
   (`.wrap` → header + `.notice` → `.summary` → Path `section` → Red flags `section`
   → Dependencies `section` → `footer`), filling from the trace facts.
3. Write the file to `out/trace-<resource>-<lang>.html` (the `out/` dir is gitignored —
   never commit real trace output). Tell the user the path and that opening it in a
   browser renders the diagram.

The file is plain HTML — it renders by double-clicking. Do not add external `<script>`
or `<link>`; keep it self-contained.

## Node icons — type → sprite key

Set the node's category color with `style="--catcolor:var(--cat-…)"` and reference the
symbol with `<use href="#nt-…"/>`.

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

| Verdict | node | badge | flag card | summary chip |
|---|---|---|---|---|
| blocker 🔴 | `node crit` | `badge crit` | `flag crit` | `chip crit` |
| warning 🟡 | `node warn` | `badge` (amber via `.warn` on flag) | `flag warn` | `chip warn` |
| pass ✅ | — | `badge ok` | one `passline` summarizing all passes | `chip pass` |
| unverified ⚪ | — | — | list under the red-flag panel | `chip unv` |

A dashed red connector (`conn dashed`) marks a broken edge in the path (e.g. DNS
resolving to a public IP). Cross-links (KV reference, inferred target) render as
`attach` chips on the source node.

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
| reachable | reachable | 到達可 |
| unreachable | unreachable | 到達不可 |
| footer | Secrets masked. Icons: azure-nettrace built-in set. | シークレットはマスク済み。アイコンは azure-nettrace 内蔵セット。 |

Red-flag titles/effects/fixes: write them in `lang`. Keep the `RF-NN` code and any
`az …` command verbatim (commands are language-neutral).

## Official icon mode (`iconStyle: official`)

The built-in sprite is license-safe and ships with the repo. Microsoft's **official**
Azure architecture icons may **not** be redistributed as a standalone set, so they are
not committed here — but you may embed them **into a generated diagram** (the permitted
use). To enable:

1. One-time: download the official set from
   <https://learn.microsoft.com/azure/architecture/icons/> and unzip it to
   `assets/azure-icons/` (this path is gitignored — do not commit it).
2. `assets/azure-icon-manifest.json` maps each resource `type` → the official SVG's
   relative path. For each node, read the mapped SVG and **inline it** in place of the
   `<use href="#nt-…"/>` (strip its width/height; let CSS size it).
3. If a mapping or file is missing, fall back to the built-in `#nt-…` symbol for that
   node and note it once in the footer.

Never commit `assets/azure-icons/` or any official SVG. The built-in set stays the
default so the skill works out of the box.
