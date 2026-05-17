// trip カード/カバー用の画像 URL を解決する共通ヘルパー。
// 画像未アップロード時は Picsum の deterministic seed 画像にフォールバックして
// デモ用見栄え向上。将来的に Active Storage で stock 画像を attach する Runner
// (もしくは Unsplash API 連動) に置き換える想定。
export function useTripImage() {
  const config = useRuntimeConfig()

  function fullImageUrl(path) {
    if (!path) return null
    if (path.startsWith("http")) return path
    const base = config.public.apiBase.replace(/\/api\/v1$/, "")
    return base + path
  }

  // 一覧カード用: trip.image_url (single, 一覧 API) があれば優先、無ければ Picsum
  function tripImage(trip, w = 600, h = 400) {
    if (trip.image_url) return fullImageUrl(trip.image_url)
    return `https://picsum.photos/seed/trip-${trip.id}/${w}/${h}`
  }

  // 詳細ヘッダ用: trip.image_urls[0] (詳細 API は複数返す) を優先、なければ
  // 一覧形式の image_url、それでも無ければ Picsum
  function coverImage(trip, w = 1200, h = 500) {
    const first = trip.image_urls?.[0] || trip.image_url
    if (first) return fullImageUrl(first)
    return `https://picsum.photos/seed/trip-${trip.id}/${w}/${h}`
  }

  return { fullImageUrl, tripImage, coverImage }
}
