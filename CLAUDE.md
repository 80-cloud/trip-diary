# CLAUDE.md — Claude Code 行動規範 (trip-diary)

> このファイルは Claude Code が毎セッション必ず読み込み、厳守するルール集です。
> 姉妹プロジェクト [80-cloud/recipe-board](https://github.com/80-cloud/recipe-board) の CLAUDE.md を**参考**にし、旅行記録アプリ独自の事情に合わせて改変しています。

---

## ⚡ Quick Reference (速見表・最重要のみ)

### 守るべき 9 つのルール

1. **Issue ファースト**: 作業前に Issue 起票 → ブランチ作成 → 実装 → PR → マージ (直接 main push 禁止)
2. **コミットメッセージ**: Conventional Commits 形式・日本語・50 字以内 (`feat:` / `fix:` / `docs:` / `chore:` 等)
3. **ブランチ名**: `feature/#番号-説明` / `fix/#番号-説明` / `docs/#番号-説明` / `chore/#番号-説明`
4. **PR**: 日本語タイトル・テンプレート使用・`Closes #番号` でリンク・Squash and merge
5. **ポート**: Rails 3010 / Nuxt 3011 / MySQL 3316 (競合時は kill して正規ポートで起動)
6. **AI 操作禁止**: `terraform destroy` / `terraform apply -auto-approve` / `aws *delete*` / `rm -rf` 等は人間承認必須
7. **`.env` などの機密情報を絶対にコミットしない** (`git status` で必ず事前確認)
8. **テストファースト**: Phase 2 以降は Issue の受け入れ条件 → テスト → 実装の順で書く (Phase 1 既存実装は smoke のみ後追い済 / 詳細 §11)
9. **Vue/Nuxt 規約**: `ref(route.query.x)` はリバース同期 watch 必須 / ヘルパー 3+ ファイル重複は composable 抽出 / `<button>` は `type="button"` / `useAsyncData` は必要なら `{deep:true}` / 権限ガードは派生集計値にも適用 (詳細 §12)

### Jidoka 発動条件 (作業中に頭をよぎったら止まる)

- 「たぶん」「だと思う」「のはず」が頭をよぎった瞬間
- 「会話で出てきたから合ってるはず」と感じた瞬間
- ビルドエラー / テスト失敗が発生した瞬間
- ユーザーが「ちょっと待って」と言った瞬間

→ いずれも **手を止め、`gh api` / `aws describe` / `curl` 等の実コマンドで裏取り**してから再開。

### 全プロジェクト共通教訓

1. ローカル設定値 (git config / npm config 等) と外部サービスのアカウント名は別物
2. 思い込みより実コマンドでの検証 (実行こそ真実)
3. 重要な固有名詞は記載前後に grep で一貫性確認
4. 仕組みが事故を防げなかった時、個人を責めず仕組みを直す

### 作業完了前の必須 4 ステップ (コードがある場合)

1. **コードレビュー**: 自分のコードを他人として読み返す + 外部識別子の事実検証
2. **テスト**: `cd backend && bin/rails test` / `cd frontend && npm test` がローカルで全 GREEN
   (PR #4 で Minitest + Vitest 基盤導入済)
3. **ビルド**: `cd backend && bin/rails zeitwerk:check` (オートロード健全性) / `cd frontend && npm run build` がエラーなく完了
4. **動作確認**: localhost:3011 (Nuxt) と localhost:3010/api/v1/* が正常応答

---

## プロジェクト概要

| 項目 | 内容 |
|---|---|
| プロジェクト名 | 旅行記録アプリ (trip-diary) |
| リポジトリ | https://github.com/80-cloud/trip-diary |
| バックエンド | Ruby 3.4.9 + Ruby on Rails 8.1 (API モード) |
| フロントエンド | Nuxt 4 + Vue 3 + Tailwind CSS (**TypeScript 不採用 = 純 JS**) |
| データベース | MySQL 8.x (Docker コンテナ) |
| 本番デプロイ | (Phase3) AWS EC2 + RDS (無料枠) |
| 作業ディレクトリ | /Users/macmini/Desktop/TripDiary |
| 提出先 | スクール講師 (Claude Code 利用は推奨されている) |
| 学習姿勢 | 「習う → 慣れる → マスター」 ([docs/学習ロードマップ.md](docs/学習ロードマップ.md)) |

---

## 1. ブランチ命名規則

作業を始める前に必ず Issue を作成し、その番号をブランチ名に含めること。

| 種別 | 命名パターン | 例 |
|---|---|---|
| 新機能 | `feature/#(番号)-(短い説明)` | `feature/#1-auth` |
| バグ修正 | `fix/#(番号)-(説明)` | `fix/#15-trip-save-bug` |
| ドキュメント | `docs/#(番号)-(説明)` | `docs/#3-readme-update` |
| 雑務・設定 | `chore/#(番号)-(説明)` | `chore/#2-setup-eslint` |

**禁止事項:**
- `main` ブランチへの直接 push は絶対禁止
- Issue 番号のないブランチ名は作成しない
- `master` ブランチは使用しない

---

## 2. Issue ファースト・ワークフロー

```
① GitHub で Issue を作成する (テンプレートを使用)
         ↓
② Issue 番号を確認する (例: #1)
         ↓
③ ブランチを作成する: git checkout -b feature/#1-説明
         ↓
④ 作業・コミットを行う
         ↓
⑤ PR を作成し、Issue を Closes #1 でリンクする
         ↓
⑥ main へマージ後、ブランチを削除する
```

---

## 3. コミットメッセージ規則

**すべてのコミットメッセージは Conventional Commits 形式で、日本語で書くこと。**

### フォーマット

```
種別: 変更の要約 (日本語・50 文字以内)

詳細説明 (任意・72 文字で折り返す)
関連する背景・理由・注意点などを書く。

Closes #(Issue番号)  ← 該当する場合のみ
```

### 種別一覧

| 種別 | 用途 |
|---|---|
| `feat` | 新機能の追加 |
| `fix` | バグの修正 |
| `docs` | ドキュメントのみの変更 |
| `style` | コードの動作に影響しない変更 (フォーマット等) |
| `refactor` | バグ修正でも機能追加でもないコード変更 |
| `test` | テストの追加・修正 |
| `chore` | ビルドツールや補助ツールの変更 |

### 補足: docs 改訂履歴の運用

- `feat` / `refactor` / `docs` (構造変更) で docs を編集した場合: 改訂履歴に新しい v 番号を追加する
- `fix` (typo / dead link / 軽微な表記揺れ修正) で docs を編集した場合: 改訂履歴の更新は **任意** (省略可)
- 判断に迷う場合は更新する側に倒す

---

## 4. プルリクエスト (PR) 規則

- **タイトルは日本語**
- 必ず `.github/pull_request_template.md` のテンプレートを使用
- 必ず関連 Issue を `Closes #番号` で本文にリンク
- main ブランチへのマージは **Squash and merge**
- PR タイトルはコミットメッセージと同形式: `種別: 説明`
- PR 作成時は必ず `--label` を付与 (Issue ラベルは PR に自動継承されない)

---

## 5. ポート割当 (重要)

trip-diary は recipe-board / sns-board と**同時起動可能**にするため、以下のポートを使う:

| サービス | ポート |
|---|---|
| Rails API | 3010 |
| Nuxt | 3011 |
| MySQL (Docker) | 3316 |

ポート競合があったら:
1. `lsof -i :3010` で何が掴んでいるか特定
2. recipe-board / sns-board のプロセスを停止
3. **絶対に「他のポートで起動する」逃げ方をしない** — 設定ファイル / docs と齟齬が出るため

---

## 6. AI が単独で実行してはいけない操作

人間承認が必須:

- `terraform destroy` / `terraform apply -auto-approve`
- `aws *delete*` / `aws *terminate*` 系
- `rm -rf` / `git push --force` / `git reset --hard origin/*`
- `DROP DATABASE` / `TRUNCATE`
- DB の本番データに対する UPDATE/DELETE
- `--no-verify` でフック迂回

---

## 7. 機密情報の取扱い

- `.env`, `*.pem`, `*.key`, `config/master.key` は **絶対にコミットしない**
- `.gitignore` で除外していることを確認
- `git add` の前に `git status` で必ず内容を確認
- 万一コミットしてしまった場合は、ローテーション + 履歴書き換えで対応

---

## 8. 環境セットアップ後の確認コマンド

```bash
# DB が立ち上がっているか
docker compose ps
# Rails API が応答するか
curl -sS http://localhost:3010/api/v1/health
# Nuxt が応答するか
curl -sS -o /dev/null -w "%{http_code}\n" http://localhost:3011
```

---

## 9. 「習う → 慣れる → マスター」の運用

Claude Code として、ユーザーが今どの段階にいるかを意識して支援する:

| 段階 | Claude の支援姿勢 |
|---|---|
| 習う | コード生成は最小限に。代わりに「なぜこう書くか」を簡潔に説明する |
| 慣れる | 動くものを早く作る。完璧主義で止めない。一連の流れを通す |
| マスター | 「他の選択肢は？」「どこに事故の芽が？」を一緒に深掘る |

詳細: [docs/学習ロードマップ.md](docs/学習ロードマップ.md)

---

## 10. 姉妹プロジェクト

| プロジェクト | 関係 |
|---|---|
| [recipe-board](https://github.com/80-cloud/recipe-board) | 技術スタック (Rails + Nuxt + MySQL + AWS) の流用元 |
| sns-board | 設計書体系 (要件定義 / 機能一覧 / ER 図 / 認証方式 / セキュリティ自己監査教訓) の参考 |
| task-board | (過去作) 一番最初に作ったタスク管理アプリ |

---

## 11. テスト運用ルール (Phase 2 以降)

### 11-1. セッション開始時の必須コマンド

作業前に必ず:

```bash
git status                    # 未コミット変更がないか確認
# 未コミット変更があれば: git stash --include-untracked   (作業途中の保護)
git switch main
git pull origin main          # 直前 PR がマージ済の場合、ローカル main を最新化
# stash していれば: git stash pop (新ブランチ作成後に戻す)
```

理由: ローカル main が古いと差分計算がズレ、不要なコンフリクト・古いコードベースに対する作業 で事故が起きる。
`git switch` は未コミット変更があると失敗するため、`git stash` で一時退避する習慣が必要。

### 11-2. 受け入れ条件先行ワークフロー

```
① Issue 作成 (機能 / バグ / 改修)
    ↓ Issue 本文に「受け入れ条件 (Given/When/Then)」を箇条書きで書く
② ブランチ作成 (feature/#N-... または docs/#N-... 等)
    ↓
③ 受け入れ条件をテストコードに 1:1 で写経 (失敗状態で commit 可)
    ↓
④ テストが緑になるよう実装を書く
    ↓
⑤ `bin/rails test` / `npm test` がローカルで全 GREEN
    ↓
⑥ PR 作成 → セルフレビュー → **CI 緑 (.github/workflows/ci.yml)** → Squash and merge
    ※ ローカル緑 ≠ CI 緑。push 後は必ず Actions の結果を確認すること
```

> 厳格な TDD (Red → Green → Refactor の順) は強制しない。「受け入れ条件を先に書く」レベルで運用。

### 11-3. テスト技法の選択指針

| 技法 | 使い分け |
|---|---|
| ホワイトボックス | モデルの `validates` / `scope` / 分岐 (Minitest model test) |
| グレーボックス | API エンドポイントの仕様 (Integration test + `login_via_api` ヘルパー) |
| ブラックボックス | UI フロー (`docs/テスト計画書.md §8` 手動チェックリスト) |
| セキュリティテスト | `docs/セキュリティ自己監査.md` の教訓集 (E-H1〜E-Proc) を回帰固定 |

詳細は [docs/テスト計画書.md](docs/テスト計画書.md) を参照。

### 11-4. Phase 1 既存実装の扱い

Phase 1 (認証 / Trip CRUD / コメント / いいね / 画像) は **smoke テストのみ後追い済** (現状 4 件・auth controller の E-H1/E-H2 回帰含む)。
Phase 2 以降の新機能・改修は本書 §11-2 のテストファースト運用に従うこと。

### 11-5. セキュリティチェック (PR テンプレと連動)

PR 作成時は `.github/pull_request_template.md` のセキュリティチェック 3 項目 (E-H1 / E-H2 / 教訓集突合) を必ず確認。
詳細は [docs/セキュリティ自己監査.md §2](docs/セキュリティ自己監査.md) 参照。

---

## 12. Vue / Nuxt コーディング規約

PR #49 (トップページ華やか化) と PR #50 (F-LEAK-01 修正) で発見した Vue/Nuxt 固有の落とし穴と共通化判断指針。新規実装・コードレビュー時に必ず突合する。

### 12-1. `ref(route.query.x)` はリバース同期 watch 必須

```js
// ❌ 片方向のみ: same-route ナビ (例: サイドナビからカテゴリリンク) で
//    URL は変わっても UI に反映されないサイレント失敗
const currentCategory = ref(route.query.category || "all")

// ✅ URL → ref のリバース同期を追加
const currentCategory = ref(route.query.category || "all")
watch(() => route.query, (q) => {
  currentCategory.value = q.category || "all"
})
```

**Why**: Nuxt SPA で `route.query` は same-route ナビゲーションで更新されるが、`ref(route.query.x)` は setup 時の初期化のみ。同値代入は Vue ref がトリガーしないため、リバース同期 watch を追加しても無限ループにはならない。

**How to apply**: `ref(route.query.x)` を書いたら必ず `watch(() => route.query)` を併記。発見契機: PR #49 のサイドナビからカテゴリ絞り込みが効かないバグ (B21)。

### 12-2. ヘルパー関数は 3 ファイル以上で重複したら composable / utility 抽出

**Why**: PR #49 で `tripImage()` が 3 ファイル (`index.vue` / `users/[id].vue` / `trips/[id]/index.vue`) で同実装重複していた → 拡張時に drift が起きるため `composables/useTripImage.js` に集約した。

**How to apply**:
- 2 箇所までのコピペは許容 (premature abstraction を避ける)
- grep で同名関数が **3 箇所以上** 見つかったら `frontend/app/composables/` に抽出
- バックエンドは `app/models/concerns/` / module 化を検討

### 12-3. `<button>` には必ず `type="button"` を付ける

```vue
<!-- ❌ form 内では既定で type="submit" → 意図せぬフォーム送信が起きる -->
<button @click="openModal">開く</button>

<!-- ✅ submit 以外は明示する -->
<button type="button" @click="openModal">開く</button>
```

**Why**: `<form>` の中の `<button>` は HTML 既定で `type="submit"`。意図しないフォーム送信や URL クエリ汚染の原因になる。

### 12-4. `useAsyncData` は mutation するなら `{ deep: true }`

```js
// Nuxt 4 から useAsyncData の data は既定で shallowRef。
// trip.value.liked_by_me = true 等の深いプロパティ代入が UI に反映されない。
const { data: trip } = await useAsyncData(`trip-${id}`, () => api.get(...), { deep: true })
```

**Why**: Nuxt 4 でデフォルトが `deep: false` (= shallowRef) に変更された。mutation を行わない参照専用ならデフォルトで OK だが、like/favorite/コメント等の sub-property 代入を行うなら `{ deep: true }` 必須。

### 12-5. 権限ガードは派生集計値 (count / sum / avg) にも適用

```ruby
# ❌ 配列だけガード、count が漏れる
planned_count: trip.planned_spots.size,
planned_spots: is_owner ? trip.planned_spots.map { ... } : []

# ✅ 派生フィールドも同じ条件でガード
planned_count: is_owner ? trip.planned_spots.size : nil,
planned_spots: is_owner ? trip.planned_spots.map { ... } : []
```

**Why**: 配列が空でも件数が漏れれば情報漏洩。詳細: [docs/セキュリティ自己監査.md](docs/セキュリティ自己監査.md) §2 E-M3。F-LEAK-01 (PR #50) で発見。

**How to apply**: serializer / payload helper をレビューする時、`is_owner ? ... : []` パターンを見つけたら、同じ配列の派生フィールド (`*_count` / `*_total` / `*_avg`) も同じ条件でガードされているか確認する。
