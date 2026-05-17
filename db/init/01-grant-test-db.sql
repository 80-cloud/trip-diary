-- MySQL コンテナ初回起動時に /docker-entrypoint-initdb.d/ から実行される。
-- docker-compose.yml の environment で指定する MYSQL_DATABASE / MYSQL_USER は
-- dev DB (trip_diary_dev) にしか権限を付与しない。
-- test DB (trip_diary_test) は Rails が `bin/rails db:test:prepare` で作成しようとするが、
-- 'trip'@'%' に CREATE 権限がないため失敗する。これを回避するため、test DB を先に
-- 作成し 'trip'@'%' に全権限を付与する。
--
-- 発見契機: B29 (2026-05-17 第 5 回セッション) — test DB 権限不足で test 失敗。
-- 当時は手動で docker exec mysql -e "GRANT ..." を流していた。本 SQL で恒久化。
--
-- 注意: init SQL は MySQL データ初期化時 (db/mysql-data が空) のみ実行される。
-- 既存環境では `docker compose down -v && docker compose up -d db` で再初期化が必要。

CREATE DATABASE IF NOT EXISTS trip_diary_test
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON trip_diary_test.* TO 'trip'@'%';
FLUSH PRIVILEGES;
