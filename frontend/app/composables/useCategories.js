// カテゴリの value/label マッピングは API (Rails enum) と一致させる。
// 増減した場合は backend/app/models/trip.rb の enum :category も同期更新すること。
export const CATEGORY_OPTIONS = [
  { value: "domestic", label: "国内" },
  { value: "overseas", label: "海外" },
  { value: "solo",     label: "一人旅" },
  { value: "gourmet",  label: "グルメ" },
  { value: "heritage", label: "世界遺産" },
  { value: "family",   label: "家族旅" },
  { value: "outdoor",  label: "アウトドア" },
  { value: "business", label: "出張" }
]

const CATEGORY_LABEL_MAP = Object.fromEntries(CATEGORY_OPTIONS.map((o) => [o.value, o.label]))

export function useCategories() {
  return {
    options: CATEGORY_OPTIONS,
    labelOf: (value) => CATEGORY_LABEL_MAP[value] || value
  }
}
