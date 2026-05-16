# 旅行記録アプリ (trip-diary) ER 図 / DB 設計書

## 改訂履歴

| 版 | 日付 | 改訂者 | 内容 |
|---|---|---|---|
| 0.1 | 2026-05-17 | hideharu-AI | 初版 (Phase1 テーブル + Phase2/3 予定テーブル) |

---

## 関連ドキュメント

- [要件定義書.md](./要件定義書.md)
- [機能一覧.md](./機能一覧.md)

---

## 1. ER 図 (Phase 1)

```
┌──────────────┐         ┌──────────────┐
│   users      │ 1     N │   trips      │ 1   N  ┌──────────────┐
├──────────────┤─────────├──────────────┤────────│ day_entries  │
│ id (PK)      │         │ id (PK)      │        ├──────────────┤
│ email        │         │ user_id (FK) │        │ id (PK)      │
│ password_dig │         │ title        │        │ trip_id (FK) │
│ display_name │         │ destination  │        │ day_number   │
│ bio          │         │ started_on   │        │ happened_on  │
│ avatar (ASt) │         │ ended_on     │        │ title        │
│ created_at   │         │ body         │        │ body         │
│ updated_at   │         │ visibility   │        │ position     │
└──────────────┘         │ likes_count  │        │ created_at   │
       │  1              │ cmts_count   │        │ updated_at   │
       │                 │ created_at   │        └──────────────┘
       │                 │ updated_at   │
       │                 └──────────────┘
       │                        │  1
       │                        │
       │                        ▼ N
       │                  ┌──────────────┐
       │  N             1 │  comments    │
       └──────────────────├──────────────┤
       │                  │ id (PK)      │
       │                  │ trip_id (FK) │
       │                  │ user_id (FK) │
       │                  │ body         │
       │                  │ created_at   │
       │                  │ updated_at   │
       │                  └──────────────┘
       │
       │  N             1
       │            ┌──────────────┐
       └────────────│   likes      │
                    ├──────────────┤
                    │ id (PK)      │
                    │ trip_id (FK) │
                    │ user_id (FK) │
                    │ created_at   │
                    │ UNIQUE(trip_id, user_id) │
                    └──────────────┘
```

加えて、Rails ActiveStorage 標準テーブル (`active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`) を利用し、`trips.images` / `users.avatar` を紐付ける。

---

## 2. テーブル定義 (Phase 1)

### 2-1. users

| カラム | 型 | NULL | デフォルト | 制約 / インデックス | 備考 |
|---|---|---|---|---|---|
| id | bigint | NO | AUTO | PK | |
| email | varchar(255) | NO | - | UNIQUE | ログイン ID |
| password_digest | varchar(255) | NO | - | - | BCrypt ハッシュ |
| display_name | varchar(30) | NO | - | - | 1〜30 文字 |
| bio | text | YES | NULL | - | 自己紹介 (Phase2) |
| created_at | datetime | NO | CURRENT | - | |
| updated_at | datetime | NO | CURRENT | - | |

### 2-2. trips

| カラム | 型 | NULL | デフォルト | 制約 / インデックス | 備考 |
|---|---|---|---|---|---|
| id | bigint | NO | AUTO | PK | |
| user_id | bigint | NO | - | FK → users.id / INDEX | 投稿者 |
| title | varchar(80) | NO | - | - | |
| destination | varchar(80) | NO | - | INDEX (Phase2 検索用) | 例: 「京都」 |
| started_on | date | NO | - | - | 開始日 |
| ended_on | date | NO | - | - | 終了日 (started ≤ ended) |
| body | text | YES | NULL | - | 全体本文 (5000 文字) |
| visibility | varchar(16) | NO | 'public' | - | public / friends / private (Phase2) |
| likes_count | int | NO | 0 | - | counter_cache |
| comments_count | int | NO | 0 | - | counter_cache |
| created_at | datetime | NO | CURRENT | INDEX (一覧ソート用) | |
| updated_at | datetime | NO | CURRENT | - | |

### 2-3. day_entries

| カラム | 型 | NULL | デフォルト | 制約 / インデックス | 備考 |
|---|---|---|---|---|---|
| id | bigint | NO | AUTO | PK | |
| trip_id | bigint | NO | - | FK → trips.id ON DELETE CASCADE / INDEX | |
| day_number | int | NO | 1 | - | 1日目 / 2日目 |
| happened_on | date | YES | NULL | - | 実日付 (任意) |
| title | varchar(80) | NO | - | - | |
| body | text | YES | NULL | - | 2000 文字 |
| position | int | NO | 0 | INDEX(trip_id, position) | 並び順 (Phase2 D&D) |
| created_at | datetime | NO | CURRENT | - | |
| updated_at | datetime | NO | CURRENT | - | |

### 2-4. comments

| カラム | 型 | NULL | デフォルト | 制約 / インデックス | 備考 |
|---|---|---|---|---|---|
| id | bigint | NO | AUTO | PK | |
| trip_id | bigint | NO | - | FK → trips.id ON DELETE CASCADE / INDEX | |
| user_id | bigint | NO | - | FK → users.id / INDEX | |
| body | varchar(140) | NO | - | - | 140 文字 |
| created_at | datetime | NO | CURRENT | INDEX (trip_id, created_at) | |
| updated_at | datetime | NO | CURRENT | - | |

### 2-5. likes

| カラム | 型 | NULL | デフォルト | 制約 / インデックス | 備考 |
|---|---|---|---|---|---|
| id | bigint | NO | AUTO | PK | |
| trip_id | bigint | NO | - | FK → trips.id ON DELETE CASCADE | |
| user_id | bigint | NO | - | FK → users.id | |
| created_at | datetime | NO | CURRENT | - | |
| - | - | - | - | UNIQUE(trip_id, user_id) | 1 人 1 記録 1 回 |

---

## 3. Rails モデルとの対応

| テーブル | モデルクラス | 関連 |
|---|---|---|
| users | `User` | `has_many :trips, dependent: :destroy` / `has_many :comments` / `has_many :likes` / `has_many :liked_trips, through: :likes, source: :trip` / `has_one_attached :avatar` |
| trips | `Trip` | `belongs_to :user` / `has_many :day_entries, dependent: :destroy` / `has_many :comments, dependent: :destroy` / `has_many :likes, dependent: :destroy` / `has_many_attached :images` / `accepts_nested_attributes_for :day_entries, allow_destroy: true` |
| day_entries | `DayEntry` | `belongs_to :trip` |
| comments | `Comment` | `belongs_to :trip, counter_cache: true` / `belongs_to :user` |
| likes | `Like` | `belongs_to :trip, counter_cache: true` / `belongs_to :user` |

---

## 4. インデックス設計の意図

| インデックス | 想定クエリ |
|---|---|
| trips(created_at DESC) | 一覧画面の新着順表示 |
| trips(user_id) | プロフィール画面で自分の記録一覧 |
| trips(destination) | Phase2 検索 (LIKE / 完全一致) |
| day_entries(trip_id, position) | 詳細画面で日付順表示 |
| comments(trip_id, created_at) | 詳細画面でコメント時系列表示 |
| likes UNIQUE(trip_id, user_id) | 1 人 1 記録 1 回の保証 |

---

## 5. Phase 2 / 3 で追加予定テーブル

| テーブル | 概要 | Phase |
|---|---|---|
| `tags` | タグ名 (unique) | 2 |
| `trip_tags` | trip ↔ tag の中間 | 2 |
| `follows` | follower_id / followed_id (UNIQUE) | 2 |
| `notifications` | recipient_id / actor_id / action / trip_id / read_at | 3 |

---

## 6. データ整合性ルール

- `Trip` 削除時は `day_entries` / `comments` / `likes` / `active_storage_attachments` を CASCADE で削除
- `User` 削除時は その人の `trips` も CASCADE 削除 (※ 講師方針が「ユーザー削除なし」なら Phase2 で軟削除へ変更可)
- カウンタ (likes_count / comments_count) は Rails `counter_cache` で自動更新。整合性は Phase3 で月次バッチで再計算

---

## 7. 初期データ (シード)

`db/seeds.rb` で以下を投入:

- ユーザー 3 名 (taro / hanako / jiro / 全員 password: `password`)
- 旅行記録 5 件 (各ユーザーに 1〜2 件)
- 出来事 各旅行に 2〜3 件
- コメント 各旅行に 1〜2 件
- いいね 各旅行に 1〜3 件
