export default {
  content: [
    "./app/**/*.{vue,js}",
    "./app.vue"
  ],
  // F-UI-DARK: useDarkMode composable で html に dark クラスを付け外しする方式
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#f0f9ff",
          500: "#0284c7",
          600: "#0369a1",
          700: "#075985"
        }
      }
    }
  },
  plugins: []
}
