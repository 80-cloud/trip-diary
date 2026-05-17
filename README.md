# 旅行記録アプリ (trip-diary)

[![CI](https://github.com/80-cloud/trip-diary/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/80-cloud/trip-diary/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-3.4.9-CC342D)](https://www.ruby-lang.org)
[![Rails](https://img.shields.io/badge/Rails-8.1-CC0000)](https://rubyonrails.org)
[![Node](https://img.shields.io/badge/Node-22-339933)](https://nodejs.org)
[![Nuxt](https://img.shields.io/badge/Nuxt-4-00DC82)](https://nuxt.com)

> 自分の旅行を時系列で記録し、複数ユーザー同士でコメント・いいね・お気に入り・フォロー・レビューを通じて反応し合える Web アプリです。
> スクール提出物として、**Ruby on Rails 8.1** + **Nuxt 4 (純 JS)** + **MySQL 8** で構築しています。

学習姿勢: **習う → 慣れる → マスター** ([docs/学習ロードマップ.md](docs/学習ロードマップ.md) 参照)

---

## 📦 講師提出物 (Deliverables)

| 提出物 | 場所 |
|---|---|
| **GitHub リポジトリ** | https://github.com/80-cloud/trip-diary |
| **README (本ファイル)** | [README.md](README.md) — 機能/技術/起動手順/テスト/カバレッジ/curl 疎通/シードユーザー |
| **設計書一式** (10 種) | [docs/](docs/) — 要件定義 / 機能一覧 / 画面設計 / ER 図 / 技術スタック / インフラ構成 / ログ・監視・障害対応 / テスト計画 / セキュリティ自己監査 / 学習ロードマップ |
| **CLAUDE.md** | [CLAUDE.md](CLAUDE.md) — Claude Code 行動規範 (Issue ファースト / Conventional Commits / テスト運用ルール) |
| **CI 実行履歴** | [Actions タブ](https://github.com/80-cloud/trip-diary/actions) — 全 PR で backend (Rails Minitest + zeitwerk) + frontend (Vitest + Nuxt build) が緑であること |
| **PR 一覧** | [Pulls (closed)](https://github.com/80-cloud/trip-diary/pulls?q=is%3Apr+is%3Aclosed) — 全機能を Issue → ブランチ → PR → セルフレビュー → CI 緑 → マージで進めた履歴 |

> **ローカル動作確認用シードユーザー**: `taro@example.com` / `password` (他 2 アカウントの一覧は本 README 下部 「シードユーザー」参照)

---

## スクリーンショット

### タイムライン (S-03)
![タイムライン](docs/screenshots/01-timeline.png)

### 旅行記録 詳細 (S-04)
![詳細](docs/screenshots/03-trip-owner.png)

### 新規作成 / 日別ネストフォーム (S-05)
![新規作成](docs/screenshots/05-new-trip.png)

---

## 主要機能

### Phase 1 (MVP) ✅ — [PR #2](https://github.com/80-cloud/trip-diary/pull/2)

- ユーザー認証 (サインアップ / ログイン / ログアウト) — JWT in HttpOnly Cookie
- 旅行記録の **CRUD** (タイトル / 行き先 / 期間 / 本文 / 公開範囲)
- 日別の出来事 (DayEntry) を **ネストフォーム**で 1 画面登録 / 編集
- 画像アップロード (ActiveStorage / 最大 5 枚)
- **コメント** (140 文字以内 / 自分のもののみ削除)
- **いいね** (1 ユーザー 1 記録 1 回 / counter_cache)

### Phase 2 (発展機能) ✅ — 6 機能群 + CI 実装済

| Phase | 機能群 | PR |
|---|---|---|
| 2-1 | **タグ / カテゴリ / 検索高度化** (多対多関連 / scope / 複合 AND 検索 / LIKE エスケープ) | [#16](https://github.com/80-cloud/trip-diary/pull/16) |
| CI | **GitHub Actions CI** (backend Rails Minitest + frontend Vitest + build を全 PR で自動実行) | [#18](https://github.com/80-cloud/trip-diary/pull/18) |
| 2-2 | **下書き / ダークモード / 無限スクロール** (enum 状態管理 / `darkMode: class` + localStorage / IntersectionObserver + cursor pagination) | [#20](https://github.com/80-cloud/trip-diary/pull/20) |
| 2-3 | **お気に入り / 個人メモ** (uniqueness 二段防衛 / upsert race rescue / 本人専用リソースの認可境界) | [#22](https://github.com/80-cloud/trip-diary/pull/22) |
| 2-4 | **フォロー / フォロー中タイムライン** (自己参照関連 / `friends`=相互フォロー可視性 / N+1 防止 pre-fetch + Set) | [#24](https://github.com/80-cloud/trip-diary/pull/24) |
| 2-5a | **計画モード / 荷物チェックリスト** (trip-owned 子リソースの CRUD / done → DayEntry 自動昇格 / 進捗集計) | [#26](https://github.com/80-cloud/trip-diary/pull/26) |
| 2-5b | **チケット管理 / 旅行レビュー** (ActiveStorage 単体添付 + MIME/size 制限 / 1 trip 1 review upsert) | [#28](https://github.com/80-cloud/trip-diary/pull/28) |

### Phase 3 (本番デプロイ) 🚧 計画中

- 通知センター (コメント / いいね / フォロー受信)
- 地図表示 (Leaflet / MapLibre)
- 統計ダッシュボード (都道府県制覇率 / 月別集計)
- S3 への画像移行
- **AWS デプロイ** (EC2 + RDS + Nginx / Terraform)

### Phase 4 (発展余地) 📅 検討中

- リアルタイム反映 (ActionCable)
- PWA (オフライン閲覧)
- 多言語 (i18n)
- PDF 出力

詳細は [docs/機能一覧.md](docs/機能一覧.md) を参照。

### テスト規模 (2026-05-17 時点)

| 種別 | 件数 | カバレッジ |
|---|---|---|
| Backend (Minitest) | 183 件 / 521 assertions GREEN | Line 89.51% / Branch 70.14% |
| Frontend (Vitest) | 12 件 GREEN | `@vitest/coverage-v8` 設定済 (`npm run test:coverage`) |

---

## 技術スタック

| レイヤー | 採用技術 |
|---|---|
| バックエンド | Ruby 3.4.9 / Rails 8.1 (API モード) |
| フロントエンド | Nuxt 4 + Vue 3 / Tailwind CSS (**TypeScript 不採用 = 純 JS**) |
| DB | MySQL 8 (Docker) |
| 認証 | JWT in HttpOnly Cookie |
| 画像 | ActiveStorage (Disk / Phase3 で S3) |
| インフラ (Phase3) | AWS EC2 + RDS + Terraform |

### 使用ポート

| サービス | ポート |
|---|---|
| Rails API | 3010 |
| Nuxt | 3011 |
| MySQL | 3316 |

> recipe-board (3000/3001/3306) と同時起動可能なよう分離しています。

---

## クイックスタート

### 前提

- macOS / Linux
- Docker Desktop インストール済み
- Ruby 3.4.9 (rbenv 等で管理)
- Node.js v22 以上

### 起動手順

```bash
# 1. クローン
git clone https://github.com/80-cloud/trip-diary.git
cd trip-diary

# 2. 環境変数を準備
cp .env.example .env
# .env を編集 (パスワード / SECRET_KEY_BASE / JWT_SECRET を設定)
# SECRET_KEY_BASE: cd backend && bundle exec rails secret
# JWT_SECRET     : openssl rand -hex 64

# 3. MySQL を起動
docker compose up -d db

# 4. バックエンドのセットアップ・起動
cd backend
bundle install
bin/rails db:create db:migrate db:seed
bin/rails s -p 3010 -b 0.0.0.0

# 5. フロントエンドのセットアップ・起動 (別ターミナル)
cd frontend
npm install
PORT=3011 npm run dev
```

ブラウザで http://localhost:3011 を開く。

### テスト実行

```bash
# バックエンド (Rails Minitest / 標準同梱)
cd backend
bin/rails db:test:prepare   # 初回 / schema 変更後
bin/rails test              # 全テスト実行

# フロントエンド (Vitest)
cd frontend
npm test                    # ワンショット実行
npm run test:watch          # 監視モード
```

テスト方針の全体像は [docs/テスト計画書.md](docs/テスト計画書.md) を参照。

### テストカバレッジ

```bash
# Backend (SimpleCov)
cd backend
bin/rails test
open coverage/index.html    # ブラウザでカバレッジ詳細を確認

# Frontend (@vitest/coverage-v8)
cd frontend
npm run test:coverage
open coverage/index.html
```

> 現状の閾値は 0% (生成のみ確認 / Phase 2 末時点の実測は backend Line 89.51%)。段階目標は [docs/ログ・監視・障害対応設計書.md §5](docs/ログ・監視・障害対応設計書.md) を参照。

### API 疎通確認 (curl)

```bash
# ヘルスチェック
curl -sS http://localhost:3010/api/v1/health

# 一覧取得 (未ログイン = 公開のみ)
curl -sS http://localhost:3010/api/v1/trips | head -c 200

# ログイン (Cookie を /tmp/c.txt に保存)
curl -sS -c /tmp/c.txt -X POST http://localhost:3010/api/v1/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"taro@example.com","password":"password"}'

# ログイン状態確認
curl -sS -b /tmp/c.txt http://localhost:3010/api/v1/me

# いいね
curl -sS -b /tmp/c.txt -X POST http://localhost:3010/api/v1/trips/2/like

# コメント投稿
curl -sS -b /tmp/c.txt -X POST http://localhost:3010/api/v1/trips/2/comments \
  -H 'Content-Type: application/json' -d '{"body":"テストコメント"}'
```

### シードユーザー (開発用)

| email | password | 役割 |
|---|---|---|
| taro@example.com | password | 一般ユーザー |
| hanako@example.com | password | 一般ユーザー |
| jiro@example.com | password | 一般ユーザー |

---

## ドキュメント

| ドキュメント | 内容 |
|---|---|
| [docs/要件定義書.md](docs/要件定義書.md) | プロジェクト目的 / 機能要件 / 非機能要件 / 講師要件マッピング |
| [docs/機能一覧.md](docs/機能一覧.md) | 機能 ID / 優先度 / Phase / 関連画面 |
| [docs/画面設計書.md](docs/画面設計書.md) | 画面一覧 / 遷移図 / ワイヤーフレーム |
| [docs/ER図.md](docs/ER図.md) | テーブル定義 / インデックス設計 |
| [docs/技術スタック.md](docs/技術スタック.md) | 採用技術と理由 |
| [docs/インフラ構成.md](docs/インフラ構成.md) | ローカル + AWS 構成 |
| [docs/ログ・監視・障害対応設計書.md](docs/ログ・監視・障害対応設計書.md) | 観測可能性 / SLI・SLO / Runbook |
| [docs/テスト計画書.md](docs/テスト計画書.md) | テストレベル / 技法 / カバレッジ目標 / 手動チェックリスト |
| [docs/セキュリティ自己監査.md](docs/セキュリティ自己監査.md) | sns-board 10 教訓の Rails 転用 + 監査結果 |
| [docs/学習ロードマップ.md](docs/学習ロードマップ.md) | 習う → 慣れる → マスター |
| [CLAUDE.md](CLAUDE.md) | Claude Code 行動規範 (Issue ファースト / Conventional Commits 等) |

### 本番デプロイ前チェックリスト (Phase 3 で実施)

- [ ] `.env` の `RAILS_ENV` を必ず `production` に変更 (development のままだと `seeds.rb` が本番 DB を汚染する — 詳細は [docs/セキュリティ自己監査.md §3 E-H3](docs/セキュリティ自己監査.md))
- [ ] `SECRET_KEY_BASE` / `JWT_SECRET` を本番用の値に差し替え (`.env.example` の値は使わない)
- [ ] `bin/rails db:seed` を本番デプロイ手順から **除外** (CI/CD パイプラインからも削除)
- [ ] `CORS_ORIGINS` を本番ドメインに限定 (`http://localhost:3011` 混入チェック)

---

## ディレクトリ構成

```
trip-diary/
├── README.md, CLAUDE.md, LICENSE, .gitignore, .env.example, docker-compose.yml
├── docs/             # 設計書一式
├── backend/          # Rails 8.1 API
├── frontend/         # Nuxt 4 (JS)
├── db/               # MySQL データ (gitignore)
├── scripts/          # 補助スクリプト
├── infra/            # (Phase3) Terraform
└── .github/          # PR / Issue テンプレ
```

---

## クレジット

- 開発: hideharu-AI (スクール在籍中)
- 技術ベース: [recipe-board](https://github.com/80-cloud/recipe-board) の構成を流用
- 設計書体系: sns-board を参考
- 開発支援: [Claude Code](https://claude.com/claude-code) (講師推奨)
