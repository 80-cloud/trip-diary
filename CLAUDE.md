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
8. **テストファースト**: Phase 2 以降は Issue の受け入れ条件 → テスト → 実装の順で書く (Phase 1 の実装にも後からテストを足した。件数は [docs/テスト計画書.md](docs/テスト計画書.md) §4 / 詳細 §11)
9. **Vue/Nuxt 規約**: `ref(route.query.x)` はリバース同期 watch 必須 / ヘルパー 3+ ファイル重複は composable 抽出 / submit でない `<button>` は `type="button"` 明示 / `useAsyncData` は必要なら `{deep:true}` / 権限ガードは派生集計値にも適用 / 未使用 `catch` 変数は `_e` prefix / `@click` で async action は handler 関数経由 / Headlessui `Menu` open 検知は slot prop 経由 / Vue 3 で `@nuxt/eslint` 導入時は `vue/no-multiple-template-root: off` 必須 / 文字の色は WCAG AA (灰色は `text-slate-500 dark:text-slate-400`・白字は `bg-brand-600`) / 入力欄は label の `for` と `id`・アイコンだけは `aria-label` / 狭い幅で文字を隠しても名前は変えない / 本人だけに出る画面も DevTools の Issues を見る (詳細 §12)

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
| 公開環境 | https://trip-diary-wpaf.onrender.com (2026-10〜。Render・TiDB Cloud Starter・Cloudinary の無料構成で公開中。構成は [docs/インフラ構成.md](docs/インフラ構成.md) §0、運用は [docs/ログ・監視・障害対応設計書.md](docs/ログ・監視・障害対応設計書.md) §7)。2026-05 に AWS (ECS Fargate + RDS) で公開し、同月に撤収した |
| 作業ディレクトリ | /Users/macmini/Desktop/Cursor/TripDiary |
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
- **テスト / perf データのクリーンアップを SQL 直 `DELETE` で行う** (必ず `bin/rails runner script/...` 経由で ActiveRecord callback (`dependent: :destroy` 等) を発火させる)
- **PR body / commit message / Issue 本文に、Claude Code のフックが止める禁止コマンドの文字列を含める** (フックはコマンドの行に書いた本文も検査するため、`gh pr create` / `gh issue create` 自体が止められる。本文は `git commit -F <ファイル>` / `--body-file <ファイル>` で渡し、禁止コマンドに触れるときは「Terraform の破壊系コマンド」のように一般化して書く)

> **B (cleanup)** の根拠: B34 (PR #81) で `DELETE FROM users` だけで子 12 テーブルの orphan が残った。`dependent: :destroy` は AR 経由でのみ発火するため、テスト/perf データ削除は `bin/rails runner script/cleanup_test_users.rb` 等を必ず経由する。
>
> **G (禁止文字列)** の根拠: B38 (PR #84) で PR body に `terraform destroy` リテラルを書いた瞬間にハードウォール作動。本文内で言及する場合は「Terraform の破壊系コマンド」のように一般化する。

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

Phase 1 (認証 / Trip CRUD / コメント / いいね / 画像) は、実装のあとからテストを足した (auth controller の E-H1/E-H2 の回帰を含む)。今の件数は [docs/テスト計画書.md](docs/テスト計画書.md) §4 を見る (ここに件数を書くと古くなるため)。
Phase 2 以降の新機能・改修は本書 §11-2 のテストファースト運用に従うこと。

### 11-5. セキュリティチェック (PR テンプレと連動)

PR 作成時は `.github/pull_request_template.md` のセキュリティチェック 3 項目 (E-H1 / E-H2 / 教訓集突合) を必ず確認。
詳細は [docs/セキュリティ自己監査.md §2](docs/セキュリティ自己監査.md) 参照。

### 11-6. lint / 静的解析ツール導入の 3 段階パターン

新規 linter を CI に組み込むときは、いきなり blocking 化せず以下の 3 段で段階的に進める:

| 段階 | 内容 | CI 設定 |
|---|---|---|
| ① auto-fix | linter の自動修正を一度回し、機械的に直せるものは PR 内で吸収 | (CI 未追加) |
| ② grandfather | CI step を追加するが `continue-on-error: true` で warning 表示のみ。残 errors を Issue 化 | `continue-on-error: true` |
| ③ blocking | 残 errors を 0 化し `continue-on-error` を削除 | (フラグなし) |

**Why**: 既存コードが大量に warning/error を吐く状態でいきなり blocking すると、CI 真っ赤 → 他作業が止まる。3 段に分けると、PR ごとに緑を維持しながら品質を段階的に上げられる。

**実証**: PR #77 (rubocop) / PR #79 (ESLint grandfather) / PR #87 (ESLint blocking 化) の 3 PR で実証済。E2E も同じ形で ③ に進めた (PR #180 で `continue-on-error` を外した)。

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

### 12-3. submit 用途以外の `<button>` には `type="button"` を明示する

```vue
<!-- ❌ form 内では既定で type="submit" → 意図せぬフォーム送信が起きる -->
<form @submit.prevent="search">
  <input v-model="query" />
  <button @click="openFilter">フィルタ</button>  <!-- ← 送信ボタン扱いになる -->
  <button type="submit">検索</button>
</form>

<!-- ✅ submit 以外は type="button" を明示 -->
<form @submit.prevent="search">
  <input v-model="query" />
  <button type="button" @click="openFilter">フィルタ</button>
  <button type="submit">検索</button>
</form>
```

**Why**: `<form>` の中の `<button>` は HTML 既定で `type="submit"`。クリックで意図しないフォーム送信が起きる。`<form>` の外でも将来 form でラップされた時に壊れないよう常に明示するのが安全。submit 用途のボタンは `type="submit"` (もしくは省略) で OK。

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

### 12-6. `catch (e)` の error 変数を使わない場合は `_e` prefix

```js
// ❌ ESLint no-unused-vars で error (catch の e が未使用)
try {
  await store.x()
} catch (e) {
  showToast("失敗しました")
}

// ✅ argsIgnorePattern: '^_' に整合
try {
  await store.x()
} catch (_e) {
  showToast("失敗しました")
}
```

**Why**: `eslint.config.mjs` で `argsIgnorePattern: '^_'` を設定済 (PR #79)。`_` prefix で「意図的に未使用」を明示すると ESLint と意図の両方を満たせる。

**How to apply**: `catch (e)` を書くとき、e を使わないなら必ず `_e` (もしくは `_err` / `_error`) に rename。発見契機: PR #79 で `useAuthStore.js` の修正 (B32)。

### 12-7. Vue template の `@click` で async action を呼ぶ場合は handler 関数経由

```vue
<!-- ❌ async store action を直結 → unhandled promise rejection -->
<button @click="store.markAllRead()">既読化</button>

<!-- ✅ handler 関数で try-catch wrap -->
<button @click="handleMarkAllRead">既読化</button>

<script setup>
const handleMarkAllRead = async () => {
  try {
    await store.markAllRead()
  } catch (_e) {
    showToast("失敗しました")
  }
}
</script>
```

**Why**: Vue template の `@click` ハンドラから返る Promise は catch されない (unhandled rejection)。エラーログがブラウザコンソールに垂れ流れ、ユーザーには何も伝わらない。

**How to apply**: `<button @click="store.xxx()">` で store の async action を直呼出しているコードを発見したら `handleXxx` で wrap する。発見契機: PR #75 NotificationsBell (B36)。

### 12-8. Headlessui `Menu` の open 検知は `<Menu v-slot="{open}">` slot prop 経由

```vue
<!-- ❌ MenuButton の @click は open/close 両方で発火 → 連打で fetch が重複 -->
<MenuButton @click="store.fetch()">通知</MenuButton>

<!-- ✅ slot prop の open を watch して open 遷移時のみ fetch -->
<Menu v-slot="{ open }">
  <MenuButton>通知</MenuButton>
  <MenuItems>...</MenuItems>
</Menu>
<!-- script setup 内で watch(() => menuOpen.value, (v) => v && store.fetch()) 相当 -->
```

**Why**: Headlessui `MenuButton` の click は open/close 両方で発火する。`@click` で fetch すると close 時にも走り無駄リクエスト。

**How to apply**: Headlessui `Menu` で open 検知が必要なら slot prop の `open` を template ref + watch で監視。連打抑制で代替する場合は `if (store.loading) return` を入れる。発見契機: PR #75 NotificationsBell (B37)。

### 12-9. Vue 3 + `@nuxt/eslint` 導入時の必須 override

`@nuxt/eslint` v1 は Vue 2 互換 rule を含むため、Vue 3 プロジェクトでは以下の override が必須:

```js
// eslint.config.mjs
export default withNuxt({
  rules: {
    "vue/no-multiple-template-root": "off", // Vue 3 は fragment 公式サポート
    // ... 他の Vue 2 限定 rule も適宜 off
  },
})
```

**Why**: Vue 3 は `<template>` 直下に複数要素 (fragment) を置けるが、Vue 2 では root 要素 1 個が必須。`@nuxt/eslint` の default config は Vue 2 互換 rule を含むため、Vue 3 で off にしないと既存コードが大量 fire する。

**How to apply**: `@nuxt/eslint` を新規導入する際は `vue/no-multiple-template-root: off` を最初から入れる。他にも Vue 3 で不要な rule (`vue/no-template-shadow` 等) があれば随時 off。発見契機: PR #79 ESLint 導入 (B31)。

### 12-10. 文字の色は WCAG AA (4.5:1) に届く組み合わせにする

```vue
<!-- ❌ 白の背景で 2.56:1 (text-slate-400) / 白字との比が 4.10:1 (bg-brand-500) -->
<p class="text-slate-400">まだ旅行はありません</p>
<button type="button" class="bg-brand-500 text-white">保存</button>

<!-- ✅ 白の背景で 4.76:1 / 白字との比が 5.93:1 -->
<p class="text-slate-500 dark:text-slate-400">まだ旅行はありません</p>
<button type="button" class="bg-brand-600 text-white hover:bg-brand-700">保存</button>
```

**Why**: #177 で、Lighthouse の Accessibility が 96 だった原因がこの 2 つの組み合わせだった。ダークの背景 (slate-800) では、逆に `text-slate-500` が 3.07:1 で届かず、`text-slate-400` なら 5.71:1 になる。

**How to apply**: 灰色の文字は `text-slate-500 dark:text-slate-400`、白字のボタンは `bg-brand-600` (hover は `bg-brand-700`) にする。`frontend/tests/style/contrast.test.js` が app の全部の `.vue` を読み、届かない組み合わせを見つける。例外は、進み具合の棒 (`h-full bg-brand-500`) と 📷 の枠 (`text-slate-300 dark:text-slate-500`) の 2 つだけ。

### 12-11. 入力欄は label の `for` と `id` でつなぎ、アイコンだけの要素には `aria-label`

```vue
<!-- ❌ placeholder だけで、label とつながっていない -->
<input v-model="newSpotTitle" placeholder="新しい計画 (例: 金閣寺)">

<!-- ✅ 見た目を変えずに名前を付ける (label は sr-only で画面に出さない) -->
<label for="plan-new-title" class="sr-only">新しい計画</label>
<input id="plan-new-title" v-model="newSpotTitle" placeholder="新しい計画 (例: 金閣寺)">

<!-- ✅ 繰り返す欄は、番号を入れた重ならない id にする -->
<label :for="`day-${d._idx}-title`" class="sr-only">Day {{ d._idx + 1 }} のタイトル</label>
<input :id="`day-${d._idx}-title`" v-model="dayEntries[d._idx].title">
```

**Why**: placeholder は label の代わりにならない。#176 (作成画面)・#189 (出来事の欄)・#196 (旅行の詳細) で、Chrome DevTools の Issues に「No label associated with a form field」と「A form field element should have an id or name attribute」が出ていた。

**How to apply**: 入力欄・選択欄・複数行の欄には、必ず `id` を付けて label とつなぐ (label で包むか、チェックボックスのように項目ごとの名前が要るものは `aria-label`)。アイコンだけのボタンとリンク (★・🚪 など) には `aria-label` を付ける。画面ごとに「すべての入力欄に id と名前がある」をテストで守る (手本は `frontend/tests/pages/tripDetail.test.js` の `gives every form field an id and a name`)。

### 12-12. 狭い幅で文字を隠しても、名前 (`aria-label`) は変えない

```vue
<!-- ✅ 640px 未満は「+」だけを見せるが、名前はどの幅でも「新しい旅行記録」 -->
<NuxtLink :to="newTripTo" aria-label="新しい旅行記録" class="bg-brand-600 text-white">
  <span class="sm:hidden">+</span>
  <span class="hidden sm:inline">+ 新しい旅行記録</span>
</NuxtLink>
```

**Why**: #176 でスマホの幅のヘッダーを短くしたとき、E2E (Playwright) は「ログアウト」などの名前でボタンを押している。幅によって名前が変わると、iPhone の E2E だけが落ちる。

**How to apply**: 見せる文字を幅で切り替えるときは、外側の要素に `aria-label` で名前を 1 つ付け、どの幅でも同じにする。名前を変える PR では、ブランチで E2E の full (Chromium・WebKit・iPhone 14) を流す。

### 12-13. ログインした本人にだけ出る画面も、DevTools の Issues を見る

**Why**: #196 で、自分の旅行の詳細にだけ出る入力欄 (計画・持ち物・チケット・予算など) が、label とつながっていなかった。Lighthouse を公開環境のログイン前のトップと 404 でしか流していなかったため、それまで気づかなかった。

**How to apply**: 画面を変える PR では、ゲストで入って自分の旅行を作り、計画と持ち物を 1 つずつ足した状態の詳細も、DevTools の Issues が 0 件かを見る (項目があるときだけ出る欄があるため)。公開環境のゲストログインは 10 分に 5 回までなので、確かめるときは入る回数を控える。
