# azure-nettrace

[English](README.md) · **日本語**

> **ステータス: 開発中** 🚧

**単一の Azure リソース**のネットワーク到達性をたどり、**インタラクティブな HTML
レポート**として描く [Claude Code](https://claude.com/claude-code) の **Agent Skill**
です。公式 Azure アイコンを使った配線図、到達性のブロッカー（赤信号）一覧、そして
各リソースを**クリックすると設定が見られる**インスペクタを備えます。

リソース名を 1 つ渡すと（App Service / VM / AKS / Function App / SQL Server /
ストレージ / API Management …）、次のように経路をたどります:

```text
リソース → VNet統合サブネット → NSG / ルートテーブル(UDR)
        → プライベートエンドポイント → プライベートDNSゾーン(VNetリンク)
        → 推定した接続先（アプリ設定 / 接続文字列 / Key Vault 参照から）
        → 接続先側のファイアウォール（networkAcls / publicNetworkAccess / DB FW規則）
```

…そして「何が繋がっているか」だけでなく、**なぜ繋がらない可能性があるか**（プライベート
DNS の VNet リンク欠落、NSG の拒否、未承認のプライベートエンドポイント、DB ファイア
ウォールが統合サブネットを許可していない、等）まで示します。

## 既存ツールとの違い

既存ツール（[azure-resource-visualizer](https://github.com/microsoft/azure-skills)、
Network Watcher トポロジ）は*リソースグループやネットワーク全体*を描きます。本スキルは
別の問いに答えます: **「この 1 リソースが、なぜあの相手に繋がらないのか？」** ——
単一リソース起点のトレース・接続先推定・到達性診断を 1 つのレポートに融合しています。

## 特長

- **結論を最初に** — 「到達可否」と、不可なら根本原因を 1 文で提示。
- **配線図** に**公式 Microsoft Azure アイコン**（任意）。断線箇所は赤で表示。
- **リソースをクリック**して設定を確認 — NSG ルール、サブネット構成、プライベート
  エンドポイントの状態、DNS の VNet リンク、SQL/ストレージのファイアウォール、他。
- **約 20 種類**に専用アダプタ（App Service / Functions / VM / AKS / Container Apps /
  SQL・PG・MySQL / ストレージ・Key Vault・Cosmos / Redis / Service Bus・Event Hubs /
  ACR / AI Search / Foundry / API Management / Application Gateway / Front Door /
  **Azure Firewall** / Data Factory・Synapse …）。その他の型は汎用フォールバックで対応。
- **出力言語** `en` / `ja`、**ダーク/ライト**対応、完全**自己完結**（閲覧にネット不要）。

## 必要なもの

- Claude Code ＋ [Azure MCP サーバー](https://github.com/Azure/azure-mcp)（推奨）。
  なければ Azure CLI に自動フォールバック
- Azure CLI 2.60 以上でサインイン済み（`az login`）、`resource-graph` 拡張
- 対象サブスクリプションの Reader 権限

## インストール

スキルを Claude Code のスキルディレクトリにリンクします:

```powershell
# Windows
New-Item -ItemType Junction -Path "$HOME\.claude\skills\azure-nettrace" `
  -Target "<repo>\skills\azure-nettrace"
```

```bash
# macOS / Linux
ln -s "<repo>/skills/azure-nettrace" "$HOME/.claude/skills/azure-nettrace"
```

Azure MCP サーバーを追加し、Azure CLI でサインインします:

```bash
az login
az extension add --name resource-graph
claude mcp add azure -- npx -y @azure/mcp@latest server start --read-only
```

そして Claude Code にこう頼みます:

> **`<あなたのApp Service名>` のネットワーク到達性をトレースして**

## 出力

既定では **自己完結のインタラクティブ HTML レポート**を `out/` に書き出します。
ブラウザで開いてください（ダーク/ライト対応・ネット不要）:

- **verdict（結論）**バンド、**配線図**、**赤信号**パネル、**依存関係テーブル**。
- **ノード**（NSG などの枝も）を**クリック**すると、そのリソースのネットワーク設定を
  インスペクタで表示。

オプション:

- **`lang`** — `ja` / `en`（指定がなければスキルが尋ねます）。
- **`format`** — `html`（既定）/ `markdown`（インライン Mermaid ＋ 表）。
- **`iconStyle`** — `builtin`（既定・ライセンス安全なアイコン）/ `official`。**公式**の
  Microsoft Azure アーキテクチャアイコンを使う場合は、セットを
  `skills/azure-nettrace/assets/azure-icons/`（gitignore 済み）にダウンロードし
  `iconStyle: official` を指定してください
  — [`references/output-html.md`](skills/azure-nettrace/references/output-html.md) 参照。

`assets/report-template.html` はそのまま開ける参考レポートです。

## サンプル

サニタイズ済みの出力例は [`examples/`](examples/) にあります:

- [正常系トレース](examples/appservice-to-sql-healthy.md) — ブロッカー 0
- [プライベートDNS欠落](examples/appservice-to-sql-broken-dns.md) — 🔴 RF-04
  （「プライベートエンドポイントは設定済みなのに繋がらない」定番ケース）

[検証環境](test-infra/) で自分でも再現できます。

## セキュリティ

トレースした構成中のシークレットは出力時にマスクされます。公式 Azure アイコンセットは
**コミットしません**（gitignore）。本リポジトリは push/PR ごとにシークレットスキャン
（gitleaks）を強制し、examples は完全にサニタイズ済みです。

## ライセンス

MIT
