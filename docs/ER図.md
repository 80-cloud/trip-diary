# 旅行記録アプリ (trip-diary) ER 図 / DB 設計書

## 改訂履歴

| 版 | 日付 | 改訂者 | 内容 |
|---|---|---|---|
| 0.1 | 2026-05-17 | hideharu-AI | 初版 (Phase1 テーブル + Phase2/3 予定テーブル) |
| 0.2 | 2026-05-17 | hideharu-AI | 機能一覧 v0.2 拡張に同期。§5 に categories / planned_spots / expenses / budgets / locations (polymorphic) / direct_messages を追加。主要関連・追加インデックス・counter_cache 候補も整理 |
| 0.3 | 2026-05-17 | hideharu-AI | 機能一覧 v0.3 (機能候補第 2 弾) に同期。§5-5 に favorites / memos / packing_items / tickets / reviews / search_histories / trip_collaborators + 既存テーブル拡張カラム (trips.status, categories.color, users.preferences, expenses.receipt, day_entries.started_at/ended_at, trips.lock_version) を整理。§5-6 統計キャッシュ戦略 / §6-2 第 2 弾削除戦略を追加 |

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

## 5. Phase 2-4 で追加予定テーブル

### 5-1. 一覧

| テーブル | 概要 | Phase |
|---|---|---|
| `categories` | id / name / slug / icon (国内 / 海外 / 一人旅 / グルメ / 世界遺産 / 家族旅 / アウトドア / 出張) | 2 |
| `tags` | name (unique) | 2 |
| `trip_tags` | trip ↔ tag の中間 (多対多) | 2 |
| (trips.category_id) | trips に category 1 件 (多対 1) のため新規ではなく **既存 trips に追加** | 2 |
| `follows` | follower_id / followed_id (UNIQUE 複合) | 2 |
| `planned_spots` | trip_id / day_entry_id (nullable) / name / planned_on / position / status (planned/visited) | 2 |
| `expenses` | trip_id / day_entry_id (nullable) / category (transport/lodging/food/sight/souvenir/other) / amount / spent_on | 2 |
| `budgets` | trip_id / category / planned_amount | 2 |
| `locations` | locatable_type (polymorphic: DayEntry / PlannedSpot) / locatable_id / latitude / longitude / address | 3 |
| `notifications` | recipient_id / actor_id / verb (commented/liked/followed) / target_type / target_id / read_at | 3 |
| `direct_messages` | sender_id / recipient_id / body / read_at | 4 |

### 5-2. 主要な関連
- `Trip belongs_to :category` (Phase 2 で追加)
- `Trip has_many :tags, through: :trip_tags`
- `Trip has_many :planned_spots, dependent: :destroy`
- `Trip has_many :expenses, dependent: :destroy`
- `Trip has_many :budgets, dependent: :destroy`
- `User has_many :active_follows, class_name: "Follow", foreign_key: :follower_id`
- `User has_many :passive_follows, class_name: "Follow", foreign_key: :followed_id`
- `User has_many :following, through: :active_follows, source: :followed`
- `User has_many :followers, through: :passive_follows, source: :follower`
- `DayEntry has_one :location, as: :locatable, dependent: :destroy`
- `PlannedSpot has_one :location, as: :locatable, dependent: :destroy`
- `Notification belongs_to :recipient, class_name: "User"` / `belongs_to :actor, class_name: "User"`

### 5-3. インデックス設計 (追加分)
- `follows UNIQUE(follower_id, followed_id)` — 1 ユーザー 1 フォロー
- `trip_tags UNIQUE(trip_id, tag_id)` — 重複付与防止
- `expenses(trip_id, spent_on)` — 日付集計
- `budgets UNIQUE(trip_id, category)` — カテゴリごとに 1 件
- `notifications(recipient_id, read_at)` — 未読絞り込み
- `direct_messages(sender_id, recipient_id, created_at)` — スレッド取得
- `locations(locatable_type, locatable_id)` — polymorphic 既定

### 5-4. counter_cache 追加候補
- `trips.planned_spots_count` / `trips.visited_spots_count` (進捗バー用)
- `users.followers_count` / `users.following_count`

### 5-5. 機能候補第 2 弾で追加するテーブル / カラム

| テーブル / カラム | 概要 | Phase | 関連機能 ID |
|---|---|---|---|
| `favorites` | user_id / trip_id / UNIQUE(user_id, trip_id) | 2 | F-FAV-01 |
| `memos` | trip_id / user_id / body (各ユーザーが他人 trip にも書ける個人メモ) | 2 | F-MEMO-01 |
| `packing_items` | trip_id / name / checked / position | 2 | F-PACK-01 |
| `tickets` | trip_id / kind (transport/lodging/event) / reservation_no / url / note + has_one_attached :file | 2 | F-TICKET-01 |
| `reviews` | trip_id / user_id / rating(1-5) / body / UNIQUE(trip_id, user_id) | 2 | F-REVIEW-01 |
| `search_histories` | user_id / query / hit_count / last_used_at | 2 | F-UX-SEARCH-HIST |
| (trips.status) | enum: draft / published — **既存 trips に追加**。`visibility` (public/friends/private) とは独立した軸: `status` = 公開フロー (作成中 / 公開済) / `visibility` = 公開範囲 (公開済になった後の閲覧範囲)。一覧 scope は `Trip.published` で絞り込み、編集画面のみ draft 表示 | 2 | F-UX-DRAFT |
| (categories.color) | hex (例: "#0284c7") — **既存 categories に追加** | 2 | F-UI-CAT-COLOR |
| (users.preferences) | **`json` 型** (dark_mode / locale 等) — **既存 users に追加**。MySQL 8 は `json` 型のみ (PostgreSQL の `jsonb` ではない点に注意) | 2 | F-UI-DARK |
| (expenses.receipt) | has_one_attached :receipt — **既存 expenses 拡張** | 2 | F-RECEIPT-01 |
| (day_entries.started_at / ended_at) | time 列追加で滞在時間集計 | 3 | F-STATS-05 |
| (trips.lock_version) | 楽観ロック (Rails 標準 ActiveRecord::Locking::Optimistic) | 4 | F-GROUP-02 |
| `trip_collaborators` | trip_id / user_id / role (viewer/editor) / invited_at / accepted_at | 4 | F-GROUP-01 |

### 5-6. 統計系のキャッシュ戦略 (Phase 3 / F-STATS-*)

- 旅行統計はオンデマンド集計 (キャッシュなし) で開始 → Trip 数 100 超で `solid_cache` ベースのキャッシュへ移行
- 都道府県制覇率は `trips.destination` の文字列マッチではなく **`Trip.prefecture` (string, enum 47 都道府県)** を追加すると正確 (Phase 3 着手時に検討)

---

## 6. データ整合性ルール

### 6-1. Phase 1 (現状)
- `Trip` 削除時は `day_entries` / `comments` / `likes` / `active_storage_attachments` を CASCADE で削除
- `User` 削除時は その人の `trips` も CASCADE 削除 (※ 講師方針が「ユーザー削除なし」なら Phase2 で軟削除へ変更可)
- カウンタ (likes_count / comments_count) は Rails `counter_cache` で自動更新。整合性は Phase3 で月次バッチで再計算

### 6-2. Phase 2-4 追加テーブルの削除戦略 (§5 / §5-5 と連動)

| 削除対象 | 連鎖削除 | 理由 |
|---|---|---|
| `Trip` 削除時 | `planned_spots` / `expenses` / `budgets` / `trip_tags` を CASCADE | 旅行記録ごとの設計・実支出データは旅行に従属 |
| `Trip` 削除時 | `notifications WHERE target_type='Trip'` を CASCADE | 通知の参照先が消えるため |
| `User` 削除時 | `follows (follower_id / followed_id 両側)` を CASCADE | フォロー関係は当事者なし → 残せない |
| `User` 削除時 | `notifications (recipient_id / actor_id 両側)` を CASCADE | 同上 |
| `User` 削除時 | `direct_messages (sender_id / recipient_id 両側)` を CASCADE | 同上 |
| `DayEntry / PlannedSpot` 削除時 | `locations` (polymorphic) を CASCADE | 位置情報は親に従属 |
| `Tag` 削除時 (Phase 2 後半) | `trip_tags` を CASCADE / `Tag` 自体は手動削除のみ | タグの孤児化を防ぐ |
| `Category` 削除時 | `Trip.category_id` を NULLIFY または `restrict_with_error` | カテゴリ削除で trip を消したくないため |
| `Trip` 削除時 (第 2 弾) | `favorites` / `memos` / `packing_items` / `tickets` / `reviews` / `trip_collaborators` を CASCADE | 旅行記録に従属 |
| `User` 削除時 (第 2 弾) | `favorites` / `memos` / `reviews` / `search_histories` / `trip_collaborators` を CASCADE | 当事者なし → 残せない |
| `Expense` 削除時 | `expenses.receipt` (ActiveStorage) を purge | 添付ファイルの孤児化を防ぐ |

### 6-3. 追加 counter_cache の整合性
- `trips.planned_spots_count` / `trips.visited_spots_count` (計画進捗バー) → counter_cache + Phase 3 で月次再計算
- `users.followers_count` / `users.following_count` → 同上
- `notifications` の未読数はキャッシュせず、`WHERE read_at IS NULL` のクエリで都度算出 (件数小)

---

## 7. 初期データ (シード)

`db/seeds.rb` で以下を投入:

- ユーザー 3 名 (taro / hanako / jiro / 全員 password: `password`)
- 旅行記録 5 件 (各ユーザーに 1〜2 件)
- 出来事 各旅行に 2〜3 件
- コメント 各旅行に 1〜2 件
- いいね 各旅行に 1〜3 件
