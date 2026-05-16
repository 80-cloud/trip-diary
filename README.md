# 旅行記録アプリ (trip-diary)

> 自分の旅行を時系列で記録し、複数ユーザー同士でコメント・いいねを通じて反応し合える Web アプリです。
> スクール提出物として、**Ruby on Rails 8.1** + **Nuxt 4 (純 JS)** + **MySQL 8** で構築しています。

学習姿勢: **習う → 慣れる → マスター** ([docs/学習ロードマップ.md](docs/学習ロードマップ.md) 参照)

---

## 主要機能

### Phase 1 (MVP) ✅ 本セッションで実装

- ユーザー認証 (サインアップ / ログイン / ログアウト) — JWT in HttpOnly Cookie
- 旅行記録の **CRUD** (タイトル / 行き先 / 期間 / 本文 / 公開範囲)
- 日別の出来事 (DayEntry) を **ネストフォーム**で 1 画面登録 / 編集
- 画像アップロード (ActiveStorage / 最大 5 枚)
- **コメント** (140 文字以内 / 自分のもののみ削除)
- **いいね** (1 ユーザー 1 記録 1 回 / counter_cache)
- プロフィール閲覧 (自分 / 他人の旅行記録一覧)

### Phase 2 (発展機能)

- 公開範囲 (`public` / `friends` / `private`)
- フォロー / フォロワー / フォロー中タイムライン
- タグ・カテゴリ
- 検索・ソート (タイトル / 行き先 / タグ)
- プロフィール編集 (表示名・自己紹介・アバター)

### Phase 3 (本番デプロイ)

- 地図表示 (Leaflet / MapLibre)
- 通知センター (コメント / いいね受信)
- S3 への画像移行
- **AWS デプロイ** (EC2 + RDS + Nginx / Terraform)

### Phase 4 (発展余地)

- リアルタイム反映 (ActionCable)
- PWA (オフライン閲覧)
- 多言語 (i18n)
- PDF 出力

詳細は [docs/機能一覧.md](docs/機能一覧.md) を参照。

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
| [docs/学習ロードマップ.md](docs/学習ロードマップ.md) | 習う → 慣れる → マスター |
| [CLAUDE.md](CLAUDE.md) | Claude Code 行動規範 (Issue ファースト / Conventional Commits 等) |

---

## ディレクトリ構成

```
trip-diary/
├── README.md, CLAUDE.md, .gitignore, .env.example, docker-compose.yml
├── docs/             # 設計書一式
├── backend/          # Rails 8.1 API
├── frontend/         # Nuxt 4 (JS)
├── db/               # MySQL データ (gitignore)
├── scripts/          # 補助スクリプト
├── infra/            # (Phase3) Terraform
└── .github/          # PR / Issue テンプレ
```

---

## ライセンス

MIT License (学習目的 / スクール提出物)

---

## クレジット

- 開発: hideharu-AI (スクール在籍中)
- 技術ベース: [recipe-board](https://github.com/80-cloud/recipe-board) の構成を流用
- 設計書体系: sns-board を参考
- 開発支援: [Claude Code](https://claude.com/claude-code) (講師推奨)
