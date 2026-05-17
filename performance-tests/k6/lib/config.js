// SLO 一元管理。要件定義書 §4-1 由来。
// 個別シナリオから import して thresholds に組み立てる。

export const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:3010';
export const FRONTEND_URL = __ENV.K6_FRONTEND_URL || 'http://localhost:3011';

// SLO (ms)。env で上書き可能 (負の試験 / 一時調整用)。
// 要件定義書 §4-1: 一覧 2.0s / 詳細 1.0s / 同時 5-10 user
export const SLO_MS = {
  timeline:    Number(__ENV.K6_THRESHOLDS_TIMELINE_MS    || 2000),
  tripDetail:  Number(__ENV.K6_THRESHOLDS_TRIP_DETAIL_MS || 1000),
  tripCreate:  Number(__ENV.K6_THRESHOLDS_TRIP_CREATE_MS || 500),
  like:        Number(__ENV.K6_THRESHOLDS_LIKE_MS        || 300),
  imageUpload: Number(__ENV.K6_THRESHOLDS_IMAGE_UPLOAD_MS || 3000),
};

// 全シナリオ共通の HTTP 失敗率上限
export const COMMON_THRESHOLDS = {
  http_req_failed: ['rate<0.01'],
};

// 本番 URL に対して 30 分高負荷をかけることを防ぐ安全装置。
// BASE_URL に amazonaws.com / cloudfront.net が含まれていたら max VU を 5 にクランプ。
export function clampVusForProduction(vus) {
  const lower = BASE_URL.toLowerCase();
  if (lower.includes('amazonaws.com') || lower.includes('cloudfront.net')) {
    if (vus > 5) {
      console.warn(`[config] BASE_URL=${BASE_URL} は本番 URL のため VU=${vus} → 5 にクランプ`);
      return 5;
    }
  }
  return vus;
}
