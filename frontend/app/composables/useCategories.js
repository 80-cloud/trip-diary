// カテゴリの value/label マッピングは API (Rails enum) と一致させる。
// 増減した場合は backend/app/models/trip.rb の enum :category も同期更新すること。
export const CATEGORY_OPTIONS = [
  { value: "domestic", label: "国内",     icon: "🏔️", gradient: "from-emerald-300 to-sky-400" },
  { value: "overseas", label: "海外",     icon: "✈️", gradient: "from-sky-300 to-indigo-500" },
  { value: "solo",     label: "一人旅",   icon: "🎒", gradient: "from-amber-300 to-rose-400" },
  { value: "gourmet",  label: "グルメ",   icon: "🍣", gradient: "from-rose-300 to-orange-400" },
  { value: "heritage", label: "世界遺産", icon: "🏛️", gradient: "from-stone-300 to-amber-500" },
  { value: "family",   label: "家族旅",   icon: "👨‍👩‍👧", gradient: "from-yellow-200 to-pink-400" },
  { value: "outdoor",  label: "アウトドア", icon: "🏕️", gradient: "from-lime-300 to-emerald-600" },
  { value: "business", label: "出張",     icon: "💼", gradient: "from-slate-400 to-zinc-600" }
]

const CATEGORY_MAP = Object.fromEntries(CATEGORY_OPTIONS.map((o) => [o.value, o]))

export function useCategories() {
  return {
    options: CATEGORY_OPTIONS,
    labelOf:    (value) => CATEGORY_MAP[value]?.label    || value,
    iconOf:     (value) => CATEGORY_MAP[value]?.icon     || "📍",
    gradientOf: (value) => CATEGORY_MAP[value]?.gradient || "from-slate-300 to-slate-500"
  }
}
