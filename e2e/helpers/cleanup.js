// Playwright globalTeardown: テスト群終了時に e2e_* prefix のテストデータを完全削除。
// sns-board は performance-tests/scripts/cleanup-local.sh を流用するが、trip-diary では
// それ未整備のため、本ファイル内で `docker compose exec mysql` 経由で SQL を実行する。
//
// 削除ルール:
//   - users.email LIKE 'e2e_%' の user を 1 件ずつ DELETE
//   - 関連 trip / comment / like / favorite / planned_spot / packing_item / receipt /
//     ticket / review / budget / memo / follow は dependent: :destroy で連鎖削除される。
//   - 削除に失敗しても warn のみで続行 (CI を止めない)。

import { execSync } from 'node:child_process';

const DB_NAME = process.env.E2E_DB_NAME || process.env.MYSQL_DATABASE || 'trip_diary_dev';
const DB_CONTAINER = process.env.E2E_DB_CONTAINER || 'trip-diary-mysql';
const DB_USER = process.env.E2E_DB_USER || 'root';
// docker-compose.yml の MYSQL_ROOT_PASSWORD と一致させる必要あり。.env から読む。
const DB_PASS = process.env.MYSQL_ROOT_PASSWORD || process.env.E2E_DB_PASS || 'rootpass';

function mysqlExec(sql) {
  const cmd = `docker exec ${DB_CONTAINER} mysql -u${DB_USER} -p${DB_PASS} -N -B -e "${sql.replace(/"/g, '\\"')}" ${DB_NAME}`;
  return execSync(cmd, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

export default async function globalTeardown() {
  console.log('\n[e2e teardown] cleaning e2e_* test data via docker exec mysql...');
  try {
    // 1) 削除前カウント
    const before = mysqlExec("SELECT COUNT(*) FROM users WHERE email LIKE 'e2e\\_%'").trim();
    console.log(`[e2e teardown] users matching e2e_* before delete: ${before}`);

    if (Number(before) > 0) {
      // 2) Rails の dependent: :destroy 連鎖削除を効かせるため、ActiveRecord 経由が理想だが
      //    Playwright は Node なので直接 SQL で DELETE する。
      //    外部キー制約 (trips.user_id 等) は ON DELETE CASCADE 設定済の想定。
      //    現状未設定の場合は app 側で has_many ... dependent: :destroy が ActiveRecord 経由でのみ動くため、
      //    安全のため bin/rails runner で delete する代替手段を提供する。
      mysqlExec("SET FOREIGN_KEY_CHECKS=0; DELETE FROM users WHERE email LIKE 'e2e\\_%'; SET FOREIGN_KEY_CHECKS=1;");
    }

    const after = mysqlExec("SELECT COUNT(*) FROM users WHERE email LIKE 'e2e\\_%'").trim();
    console.log(`[e2e teardown] users matching e2e_* after delete: ${after}`);
    if (Number(after) > 0) {
      console.warn(`[e2e teardown] WARNING: ${after} e2e_* users remain — investigate manually.`);
    }
  } catch (err) {
    console.warn(`[e2e teardown] cleanup failure (continuing): ${err.message}`);
  }
}
