// 公開環境では新規登録を止めるため、画面のサインアップ導線を出し分ける (F-AUTH-01 / P0-9)。
// 値は nuxt.config の runtimeConfig.public.signupEnabled (ビルド時に決まる)。
// 未設定は有効とし、実行時の環境変数で文字列 "false" が入った場合も無効として扱う。
// 画面は導線を隠すだけで、登録そのものは API 側 (SIGNUP_ENABLED) が 403 で止める。
export function useSignupEnabled() {
  const value = useRuntimeConfig().public.signupEnabled
  return value !== false && value !== "false"
}
