# performance-tests/ — trip-diary on-demand パフォーマンステスト

要件定義書 §4-1 / 承認済みロードマップ Pivot-4 準拠。

このディレクトリは **任意タイミングで実行する** パフォーマンステスト基盤。`ci.yml` (毎 PR) には統合せず、別 workflow (`.github/workflows/perf.yml`) で `workflow_dispatch` (手動) + `schedule` (月次) で実行する。

## 構成 (4 layer 想定)

| Layer | ツール | 対象 | 実装状態 |
|---|---|---|---|
| **A. API 負荷** | k6 (protocol) | Rails REST API | ✅ smoke + timeline + **trip_create + trip_detail + like + soak** (PR-H 完了) / image_upload は別 Issue |
| B. ブラウザ E2E | k6 browser (Chromium) | Nuxt UI 実操作 | 📅 PR-I (Web Vitals 計測) |
| C. Frontend 単発 | Lighthouse CLI | 主要ページ Web Vitals | 📅 PR-J (4 page audit) |
| D. N+1 回帰 | Bullet gem (development) | ActiveRecord クエリ | ✅ 既に組込済 (PR #32 / Rails dev mode で自動検出) |

## SLO (要件定義書 §4-1)

| 操作 | 目標 | scenario | 状態 |
|---|---|---|---|
| **タイムライン取得** (`GET /api/v1/trips`) | **p95 < 2.0 秒** | `timeline.js` | ✅ PR #71 |
| **trip 詳細** (`GET /api/v1/trips/:id`) | **p95 < 1.0 秒** | `trip_detail.js` | ✅ PR-H |
| **trip 作成** (`POST /api/v1/trips`) | **p95 < 0.5 秒** | `trip_create.js` | ✅ PR-H |
| **いいね追加/取消** (`POST/DEL /api/v1/trips/:id/like`) | **p95 < 0.3 秒** | `like.js` | ✅ PR-H |
| **30 分 soak (mixed)** | failure < 1% / 各 SLO 維持 | `soak.js` | ✅ PR-H |
| 画像アップロード | p95 < 3.0 秒 | (未実装 / 別 Issue) | 📅 ActiveStorage direct_uploads 設計検討 |

## 前提

| 必須 | 入手 |
|---|---|
| k6 v0.50+ (本 PR は v2.0+ で動作確認) | `brew install k6` |
| Docker Desktop (MySQL container 用) | `brew install --cask docker` |
| Rails (port 3010) / MySQL (port 3316) 起動済 | `/start-servers` skill 推奨 |

### VU > 3 で実行する場合の必須セットアップ

rack-attack が signup を **3 req/分/IP** に制限している ([backend/config/initializers/rack_attack.rb](../backend/config/initializers/rack_attack.rb))。perf テストは複数 VU が短時間に signup するため、3 を超える VU では throttle で 429 が連発し測定不能になる。

**回避策**: Rails 起動時に `RACK_ATTACK_DISABLED=1` を渡す (opt-in / 本番では絶対設定しないこと):

```bash
# Rails を停止して再起動
cd backend
RACK_ATTACK_DISABLED=1 bin/rails s -p 3010
```

perf テスト完了後は環境変数なしで再起動して既定の throttle を復旧させる。

## 実行

```bash
cd performance-tests

# .env から MySQL 認証情報を export
set -a && source ../.env && set +a

# Layer A: API 負荷
npm run perf:smoke              # 全 endpoint 200 確認 (最短)
npm run perf:timeline           # GET /api/v1/trips SLO assert (p95 < 2.0s)
npm run perf:trip_create        # POST /api/v1/trips SLO assert (p95 < 0.5s)
npm run perf:trip_detail        # GET /api/v1/trips/:id SLO assert (p95 < 1.0s)
npm run perf:like               # POST/DEL /api/v1/trips/:id/like SLO assert (p95 < 0.3s)
npm run perf:soak               # 30 min mixed workload (VU=5 / Layer A 総仕上げ)

# クリーンアップ (各 scenario 完了後・soak 後は特に重要)
npm run perf:cleanup            # MySQL から perf_* user を ActiveRecord 経由で削除
npm run perf:verify-clean       # 残骸 0 件を確認
```

SLO を意図的に違反させて fail することの確認:

```bash
K6_THRESHOLDS_TIMELINE_MS=10    npm run perf:timeline
K6_THRESHOLDS_TRIP_CREATE_MS=10 npm run perf:trip_create
K6_THRESHOLDS_LIKE_MS=10        npm run perf:like
```

soak を短時間で動作確認する場合 (デフォルト 30m → 30s):

```bash
K6_DURATION=30s npm run perf:soak
```

## クリーンアップの 3 段防御

1. **命名規約**: 全テストデータに `perf_<RUN_ID>_` 接頭辞。RUN_ID = `YYYYMMDD_HHMMSS_<rand6>`
   - E2E は `e2e_` prefix で分離 (e2e/helpers/cleanup.js)
2. **scenario 完了後の手動 cleanup**: `npm run perf:cleanup`
   - 内部で `bin/rails runner script/cleanup_test_users.rb` を呼び出し
     (Issue #72 で改修: SQL 直接 DELETE → ActiveRecord `dependent: :destroy` 連鎖)
   - trip / comment / like / favorite / memo / planned_spot / packing_item / ticket /
     review / budget / receipt / day_entry / trip_tag / notification / follow まで
     完全に連鎖削除されて orphan 0 が保証される
   - Rails 起動コスト 10-30 秒
3. **削除後の verify**: `npm run perf:verify-clean` で `perf_%` 件数 = 0 を assert

## 環境変数

| 変数 | デフォルト | 用途 |
|---|---|---|
| `K6_BASE_URL` | `http://localhost:3010` | Rails API ベース URL |
| `K6_FRONTEND_URL` | `http://localhost:3011` | Nuxt URL (k6 browser / Lighthouse 用 / 本 PR は未使用) |
| `K6_RUN_ID` | 自動生成 | テストデータ識別子。指定すると seed と cleanup が同 ID を共有 |
| `K6_VUS` | scenario 依存 | 仮想ユーザ数の上書き |
| `K6_DURATION` | scenario 依存 | 実行時間の上書き |
| `K6_THRESHOLDS_TIMELINE_MS` | `2000` | timeline SLO ms |
| `K6_THRESHOLDS_TRIP_DETAIL_MS` | `1000` | trip detail SLO ms |
| `K6_THRESHOLDS_TRIP_CREATE_MS` | `500` | trip create SLO ms |
| `K6_THRESHOLDS_LIKE_MS` | `300` | like add/remove SLO ms |
| `K6_THRESHOLDS_IMAGE_UPLOAD_MS` | `3000` | image upload SLO ms (未実装) |
| `K6_SOAK_CREATE_EVERY` | `50` | soak: N iter に 1 回 trip_create を実行 (DB 肥大化抑制) |
| `K6_SOAK_SLEEP` | `1` | soak: iter 間 sleep 秒 (req/min 流量緩和 / 0 で無休) |
| `DB_HOST` / `MYSQL_PORT` / `MYSQL_USER` / `MYSQL_PASSWORD` | (.env 経由) | cleanup-local.sh が呼び出す `bin/rails runner` の DB 接続情報 |

## 本番への負荷テストは禁止

`K6_BASE_URL` に `amazonaws.com` / `cloudfront.net` が含まれていた場合、`config.js` の `clampVusForProduction()` が **VU を 5 にクランプ + warning** を出す安全装置あり。30 分高負荷はローカル Docker のみで実施。

## CI 統合

[.github/workflows/perf.yml](../.github/workflows/perf.yml) で以下のトリガで実行:

- `workflow_dispatch` (手動 / Actions UI から `target_env=local` + `scenario` 選択)
- `schedule` (月次 cron / 毎月 1 日 03:00 UTC = 12:00 JST / smoke 自動実行 / 性能 regression 早期検知)

毎 PR で実行しない理由: perf は遅い + flaky の余地があり CI 全体を遅くする。

## トラブルシュート

| 症状 | 対処 |
|---|---|
| `k6: command not found` | `brew install k6` |
| `docker exec: container not running` | `docker compose up -d` で MySQL container 起動 |
| `Access denied for user 'root'` | `set -a && source ../.env && set +a` で MYSQL_ROOT_PASSWORD を export |
| 残骸検知 (`verify-no-residue.sh` が exit 1) | `npm run perf:cleanup` を手動実行 |

## 関連ドキュメント

- [要件定義書.md §4-1](../docs/要件定義書.md) (SLO の根拠)
- [テスト計画書.md](../docs/テスト計画書.md) (perf 全体方針 / Pivot-5 で改訂予定)
- [機能一覧.md F-PERF-01](../docs/機能一覧.md) (Phase 3 スコープ)
