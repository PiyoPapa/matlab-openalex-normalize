# matlab-openalex-normalize
**Language:** [English](README.md) | 日本語

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=PiyoPapa/matlab-openalex-normalize)

標準化OpenAlex Works JSONL を、MATLAB で固定スキーマの CSV に正規化します。
本リポジトリは、OpenAlex メタデータを再現性があり、
時間的に区切られた探索用途のための、バージョン管理された CSV ファイルへ変換する
**保守的な正規化レイヤー**を提供します。

## Overview
本リポジトリは、標準 OpenAlex Works JSONL を
**安定した検査可能な CSV ファイル**へ変換するための
**保守的な正規化レイヤー**を提供します。

**本リポジトリが提供するもの**
- 標準 OpenAlex JSONL（1 行 = 1 Work）からの決定論的な正規化
- 安定した主キーを持つ、固定・バージョン管理された CSV スキーマ
- 入力、バージョン、エラーを記録する必須の `run_manifest.json`

**本リポジトリが提供しないもの**
- OpenAlex からのデータ取得
- セマンティック解析、埋め込み、クラスタリング、可視化
- 被引用ネットワークや大規模グラフ構築
- スキーマ正規化を超える自動クレンジング、重複除去、最適化

## Repository position in the OpenAlex–MATLAB workflow
本リポジトリは、3 段階からなるワークフローのうち、
**正規化レイヤー**を担います。

1. **Acquisition** — OpenAlex Works の取得  
   → [`matlab-openalex-pipeline`](https://github.com/PiyoPapa/matlab-openalex-pipeline)

2. **Normalization** — 固定スキーマのバージョン管理 CSV（**本リポジトリ**）  
   → [`matlab-openalex-normalize`](https://github.com/PiyoPapa/matlab-openalex-normalize)

3. **Analysis / topic mapping** — 診断的可視化およびセマンティックマップ  
   → [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)

## Who this repository is for
本リポジトリは、以下の用途を想定しています。
- **標準 OpenAlex Works JSONL** をすでに保有しており、
  **検査可能な固定スキーマ CSV** が必要なユーザー
- 明示的な実行メタデータ（`run_manifest.json`）を伴う
  **再現可能な出力**が求められるワークフロー

本リポジトリは、以下の用途を想定していません。
- OpenAlex からのデータ取得（`matlab-openalex-pipeline` を使用してください）
- 解析やトピックマッピング（`matlab-openalex-analyze` を使用してください）

## Scope and non-goals
### In scope
- 標準化 OpenAlex JSONL から、固定・バージョン管理された CSV スキーマへの決定論的正規化
- 入力、バージョン、正規化エラーを記録する明示的な実行マニフェスト

### Out of scope
- データ取得、セマンティック解析、埋め込み、クラスタリング、可視化、グラフ構築
- スキーマ正規化を超える自動クレンジング、重複除去、最適化

本リポジトリは、以下を優先します。
- 利便性より再現性
- 抽象化より透明性
- 隠れたデフォルトより明示的な設定

## Repository layout
- `src/` — 中核となる正規化ロジックおよびスキーマ別ライター
- `data_processed/` — ユーザーが作成する、実行単位の出力フォルダ
- `docs/` — スキーマ注記や補足ドキュメント（存在する場合）

## Input / Output
### Input
- **標準化 JSONL のみ**（`1 行 = 1 Work`）
- 配列形式の JSONL は、正規化前に変換が必要です

### Output
- すべての出力は `data_processed/<YYYYMMDD_HHMM>_n<records>/` 配下に書き出されます
- `run_manifest.json` は常に生成され、入力、バージョン、エラーを記録します
- CSV ファイルは UTF-8 エンコードで、バージョンごとに固定スキーマに従います

CSV 出力は、中間的かつ交換しやすい形式として意図されています。
非常に大規模なデータセットについては、
下流でデータベースやカラム指向ストレージの利用が推奨されます。

## Demos / Examples
本リポジトリ内の例は、正規化挙動およびスキーマ確認に限定した、
意図的に最小限のものです。
解析、可視化、セマンティックな例は、下流のリポジトリで管理されています。

## When to stop here / when to move on
- 以下の場合は、ここで止めて問題ありません。
  - 下流処理のために、マニフェスト付きの安定した CSV 出力のみが必要な場合
- 以下が必要な場合は、次の段階へ進んでください。
  - 診断的解析、セマンティックな確認、トピックマッピング  
  → [`matlab-openalex-analyze`](https://github.com/PiyoPapa/matlab-openalex-analyze)

## Schema / column definitions

### Schema versions
- **v0.1**: 固定カラムによる最小安定セット
- **v0.2**: 後方互換の拡張（v0.1 カラムの変更なし）

#### v0.1 outputs
以下を正確に生成します。
- `works.csv`
- `authorships.csv`
- `concepts.csv`

#### v0.2 extensions
- `sources.csv`（v0.2.0）
- オプション出力（v0.2.3+）:
  - `institutions.csv`
  - `counts_by_year.csv`

オプション出力は、書き込みに失敗しても正規化処理を停止しません。
失敗は `run_manifest.json` に記録されます。

### Column definitions (v0.1)

**works.csv**
- work_id (string, OpenAlex URL)
- doi (string, nullable)
- title (string, nullable)
- publication_year (int, nullable)
- publication_date (string, nullable)
- type (string, nullable)
- language (string, nullable)
- cited_by_count (int, nullable)
- is_oa (bool, nullable)
- oa_status (string, nullable)

**authorships.csv**
- work_id (string)
- author_id (string)
- author_display_name (string, nullable)
- author_orcid (string, nullable)
- author_position (string, nullable)
- is_corresponding (bool, nullable)
- institution_id (string, nullable)
- institution_display_name (string, nullable)
- country_code (string, nullable)

**concepts.csv**
- work_id (string)
- concept_id (string)
- concept_display_name (string, nullable)
- concept_level (int, nullable)
- concept_score (double, nullable)

**Limitations**
- 各オーサーシップにつき、最初の所属機関のみが `authorships.csv` に保存されます
- アブストラクトのプレーンテキストおよび URL フィールドは、意図的に除外されています

## Installation / Quick start

### Installation
本リポジトリをクローンし、`src/` を MATLAB パスに追加してください。

```matlab
addpath(genpath("src"));
```

### Quick start
1. （必要に応じて）pipeline JSONL を標準 JSONL に変換
2. 正規化を実行

```matlab
inJsonl = "data/openalex_MATLAB_cursor_en.standard.jsonl";
outDir  = fullfile("data_processed", "20251216_0815_n10000");

normalize_openalex(inJsonl, outDir, ...
    "schemaVersion","v0.1", ...
    "verbose",true);
```

## Disclaimer
著者は MathWorks Japan の従業員です。
本リポジトリは、個人的かつ独立した実験プロジェクトとして開発されたものであり、
MathWorks の製品、サービス、公式コンテンツの一部ではありません。
MathWorks は、本リポジトリをレビュー、保証、サポート、保守することはありません。
すべての見解および実装は、著者個人のものです。

## License
MIT License。詳細は LICENSE ファイルを参照してください。

## Notes
本リポジトリは、以下を優先します。
- 利便性より再現性
- 抽象化より透明性
- 隠れたデフォルトより明示的な設定

本プロジェクトはベストエフォートで維持されており、公式なサポートは提供されません。
バグ報告や質問については、GitHub Issues を使用してください。
