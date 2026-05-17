// Playwright spec / fixture から直接 Rails API を叩く fetch ラッパー (sns-board 踏襲)。
// ブラウザ操作と独立にデータ準備 (signup / trip 作成 / コメント / いいね) したい場面で使う。
//
// 認証: trip-diary は encrypted JWT を Cookie `trip_diary_token` に格納
// (backend/app/controllers/application_controller.rb COOKIE_NAME)。
// 同 ApiSession 内では signup 時の Cookie をそのまま後続 API に流用する
// (Node fetch 上で Cookie ヘッダーに直接付与すれば Rails が decrypt 可能)。
//
// ブラウザ側の認証は別途 UI login で行う設計 (fixtures/auth-state.js 参照)。
// Rails encrypted cookie 値を Playwright BrowserContext.addCookies に渡すと
// format が一致せず壊れるため、ブラウザへの cookie 直接注入は採用しない。

import { makeEmail, makeDisplayName, tagTripTitle, DEFAULT_PASSWORD } from './naming.js';

const BACKEND_URL = process.env.E2E_BACKEND_URL || 'http://localhost:3010';
const API_BASE = `${BACKEND_URL}/api/v1`;

export class ApiSession {
  constructor() {
    this.cookies = new Map();
    this.user = null;
  }

  _cookieHeader() {
    return Array.from(this.cookies.entries()).map(([n, v]) => `${n}=${v}`).join('; ');
  }

  _ingestSetCookie(res) {
    const setCookies = res.headers.getSetCookie?.() || [];
    for (const sc of setCookies) {
      const [pair] = sc.split(';');
      const eq = pair.indexOf('=');
      if (eq < 0) continue;
      const name = pair.slice(0, eq).trim();
      const value = pair.slice(eq + 1).trim();
      if (name) this.cookies.set(name, value);
    }
  }

  async signup(index) {
    const email = makeEmail(index);
    const display_name = makeDisplayName(index);
    const res = await fetch(`${API_BASE}/signup`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, display_name, password: DEFAULT_PASSWORD }),
    });
    if (res.status !== 201) {
      throw new Error(`signup ${index} failed: ${res.status} ${await res.text()}`);
    }
    this._ingestSetCookie(res);
    const json = await res.json();
    this.user = json.user;
    return { email, display_name, password: DEFAULT_PASSWORD, user: json.user };
  }

  async login(email, password) {
    const res = await fetch(`${API_BASE}/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    if (res.status !== 200) {
      throw new Error(`login failed: ${res.status} ${await res.text()}`);
    }
    this._ingestSetCookie(res);
    const json = await res.json();
    this.user = json.user;
    return json.user;
  }

  async createTrip({ title, destination = '京都', body = '', category = 'domestic', startedOn, endedOn } = {}) {
    const today = new Date();
    const fmt = (d) => d.toISOString().slice(0, 10);
    const start = startedOn || fmt(today);
    const end = endedOn || fmt(today);
    const res = await fetch(`${API_BASE}/trips`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Cookie: this._cookieHeader(),
      },
      body: JSON.stringify({
        title: tagTripTitle(title || 'smoke trip'),
        destination,
        started_on: start,
        ended_on: end,
        body,
        category,
        visibility: 'public',
        status: 'published',
      }),
    });
    if (res.status !== 201) {
      throw new Error(`createTrip failed: ${res.status} ${await res.text()}`);
    }
    return res.json();
  }

  async createComment(tripId, body) {
    const res = await fetch(`${API_BASE}/trips/${tripId}/comments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Cookie: this._cookieHeader(),
      },
      body: JSON.stringify({ body }),
    });
    if (res.status !== 201) {
      throw new Error(`createComment failed: ${res.status} ${await res.text()}`);
    }
    return res.json();
  }

  async likeTrip(tripId) {
    const res = await fetch(`${API_BASE}/trips/${tripId}/like`, {
      method: 'POST',
      headers: { Cookie: this._cookieHeader() },
    });
    if (res.status !== 200 && res.status !== 201) {
      throw new Error(`likeTrip failed: ${res.status} ${await res.text()}`);
    }
    return res.json();
  }
}

